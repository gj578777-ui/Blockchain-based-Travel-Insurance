(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-POLICY u101)
(define-constant ERR-INVALID-CLAIM-AMOUNT u102)
(define-constant ERR-INVALID-EVENT-TYPE u103)
(define-constant ERR-CLAIM-ALREADY-PROCESSED u104)
(define-constant ERR-ORACLE-DATA-INVALID u105)
(define-constant ERR-POLICY-EXPIRED u106)
(define-constant ERR-INSUFFICIENT-COVERAGE u107)
(define-constant ERR-DISPUTE-IN_PROGRESS u108)
(define-constant ERR-PAYOUT-FAILED u109)
(define-constant ERR-INVALID-STATUS u110)
(define-constant ERR-CLAIM-NOT-FOUND u111)
(define-constant ERR-INVALID-CLAIMANT u112)
(define-constant ERR-MAX-CLAIMS-EXCEEDED u113)
(define-constant ERR-INVALID-DETAILS u114)
(define-constant ERR-INVALID-THRESHOLD u115)
(define-constant ERR-AUDIT-LOG-FAILED u116)
(define-constant ERR-DISPUTE_RESOLUTION_FAILED u117)
(define-constant ERR-ORACLE_NOT_VERIFIED u118)
(define-constant ERR-POLICY_NOT_ACTIVE u119)
(define-constant ERR-INVALID_COVERAGE_TYPE u120)

(define-data-var last-claim-id uint u0)
(define-data-var max-claims uint u10000)
(define-data-var processing-fee uint u100)
(define-data-var oracle-contract (optional principal) none)

(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    status: (string-ascii 20),
    amount: uint,
    event-type: uint,
    details: (string-ascii 100),
    timestamp: uint,
    payout-amount: uint,
    disputed: bool
  }
)

(define-map claim-disputes
  { claim-id: uint }
  {
    resolver: principal,
    resolution-timestamp: uint,
    resolved-status: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

(define-read-only (get-claim (id uint))
  (map-get? claims { claim-id: id })
)

(define-read-only (get-claim-dispute (id uint))
  (map-get? claim-disputes { claim-id: id })
)

(define-read-only (is-claim-processed (id uint))
  (match (get-claim id)
    claim (is-eq (get status claim) "processed")
    false
  )
)

(define-private (validate-principal (p principal))
  (if (not (is-eq p 'SP000000000000000000002Q6VF78))
      (ok true)
      (err ERR-NOT-AUTHORIZED)
  )
)

(define-private (validate-policy (policy-id uint))
  (let ((policy (unwrap! (contract-call? .PolicyFactory get-policy policy-id) (err ERR-INVALID-POLICY))))
    (if (and (get active policy) (<= block-height (get expiry policy)))
        (ok policy)
        (err ERR-POLICY-EXPIRED)
    )
  )
)

(define-private (validate-claimant (claimant principal) (policy-owner principal))
  (if (is-eq claimant policy-owner)
      (ok true)
      (err ERR-INVALID-CLAIMANT)
  )
)

(define-private (validate-event-type (event-type uint) (coverage-type uint))
  (if (is-eq event-type coverage-type)
      (ok true)
      (err ERR-INVALID-EVENT-TYPE)
  )
)

(define-private (validate-details (details (string-ascii 100)))
  (if (and (> (len details) u0) (<= (len details) u100))
      (ok true)
      (err ERR-INVALID-DETAILS)
  )
)

(define-private (validate-oracle-data (oracle-data (tuple (event-type uint) (details (string-ascii 100)))))
  (let ((oracle (unwrap! (var-get oracle-contract) (err ERR-ORACLE_NOT_VERIFIED))))
    (match (contract-call? .OracleIntegrator verify-data oracle-data oracle)
      success (ok oracle-data)
      error (err ERR-ORACLE-DATA-INVALID)
    )
  )
)

(define-private (validate-amount (amount uint))
  (if (> amount u0)
      (ok true)
      (err ERR-INVALID-CLAIM-AMOUNT)
  )
)

(define-private (calculate-payout (claim-amount uint) (coverage-amount uint))
  (if (<= claim-amount coverage-amount)
      (ok claim-amount)
      (err ERR-INSUFFICIENT-COVERAGE)
  )
)

(define-private (log-audit (claim-id uint) (action (string-ascii 50)))
  (match (contract-call? .AuditLogger log-event claim-id action block-height tx-sender)
    success (ok true)
    error (err ERR-AUDIT-LOG-FAILED)
  )
)

(define-private (initiate-dispute (claim-id uint))
  (match (contract-call? .DisputeResolver start-dispute claim-id tx-sender)
    success (ok true)
    error (err ERR-DISPUTE_RESOLUTION_FAILED)
  )
)

(define-public (set-oracle-contract (contract-principal principal))
  (begin
    (try! (validate-principal contract-principal))
    (if (is-eq tx-sender contract-caller)
        (begin
          (var-set oracle-contract (some contract-principal))
          (ok true)
        )
        (err ERR-NOT-AUTHORIZED)
    )
  )
)

(define-public (set-max-claims (new-max uint))
  (begin
    (try! (validate-amount new-max))
    (if (is-eq tx-sender contract-caller)
        (begin
          (var-set max-claims new-max)
          (ok true)
        )
        (err ERR-NOT-AUTHORIZED)
    )
  )
)

(define-public (set-processing-fee (new-fee uint))
  (begin
    (try! (validate-amount new-fee))
    (if (is-eq tx-sender contract-caller)
        (begin
          (var-set processing-fee new-fee)
          (ok true)
        )
        (err ERR-NOT-AUTHORIZED)
    )
  )
)

(define-public (process-claim (policy-id uint) (oracle-data (tuple (event-type uint) (details (string-ascii 100)))))
  (let
    (
      (claim-id (+ (var-get last-claim-id) u1))
      (policy (try! (validate-policy policy-id)))
      (coverage (try! (contract-call? .CoverageRegistry get-coverage (get type policy))))
      (validated-data (try! (validate-oracle-data oracle-data)))
      (event-type (get event-type validated-data))
      (details (get details validated-data))
    )
    (try! (validate-claimant tx-sender (get owner policy)))
    (try! (validate-event-type event-type (get type policy)))
    (try! (validate-details details))
    (asserts! (< (var-get last-claim-id) (var-get max-claims)) (err ERR-MAX-CLAIMS-EXCEEDED))
    (let ((payout (try! (calculate-payout (get coverage-amount coverage) (get premium policy)))))
      (map-set claims { claim-id: claim-id }
        {
          policy-id: policy-id,
          claimant: tx-sender,
          status: "pending",
          amount: payout,
          event-type: event-type,
          details: details,
          timestamp: block-height,
          payout-amount: u0,
          disputed: false
        }
      )
      (try! (log-audit claim-id "claim-initiated"))
      (match (contract-call? .PayoutManager trigger-payout claim-id payout tx-sender)
        success
          (begin
            (map-set claims { claim-id: claim-id } (merge (unwrap-panic (get-claim claim-id)) { status: "processed", payout-amount: payout }))
            (try! (log-audit claim-id "payout-success"))
            (var-set last-claim-id claim-id)
            (ok claim-id)
          )
        error
          (begin
            (map-set claims { claim-id: claim-id } (merge (unwrap-panic (get-claim claim-id)) { status: "disputed", disputed: true }))
            (try! (initiate-dispute claim-id))
            (try! (log-audit claim-id "payout-failed-dispute"))
            (err ERR-PAYOUT-FAILED)
          )
      )
    )
  )
)

(define-public (resolve-dispute (claim-id uint) (resolved-status (string-ascii 20)) (notes (string-ascii 200)))
  (let ((claim (unwrap! (get-claim claim-id) (err ERR-CLAIM-NOT-FOUND))))
    (asserts! (get disputed claim) (err ERR-DISPUTE_IN_PROGRESS))
    (asserts! (is-eq tx-sender (unwrap! (contract-call? .DisputeResolver get-resolver claim-id) (err ERR-NOT-AUTHORIZED))) (err ERR-NOT-AUTHORIZED))
    (map-set claim-disputes { claim-id: claim-id }
      {
        resolver: tx-sender,
        resolution-timestamp: block-height,
        resolved-status: resolved-status,
        notes: notes
      }
    )
    (if (is-eq resolved-status "approved")
        (match (contract-call? .PayoutManager trigger-payout claim-id (get amount claim) (get claimant claim))
          success
            (begin
              (map-set claims { claim-id: claim-id } (merge claim { status: "processed", payout-amount: (get amount claim), disputed: false }))
              (try! (log-audit claim-id "dispute-resolved-approved"))
              (ok true)
            )
          error (err ERR-PAYOUT-FAILED)
        )
        (begin
          (map-set claims { claim-id: claim-id } (merge claim { status: "rejected", disputed: false }))
          (try! (log-audit claim-id "dispute-resolved-rejected"))
          (ok true)
        )
    )
  )
)

(define-public (get-claim-status (claim-id uint))
  (match (get-claim claim-id)
    claim (ok (get status claim))
    (err ERR-CLAIM-NOT-FOUND)
  )
)

(define-public (cancel-claim (claim-id uint))
  (let ((claim (unwrap! (get-claim claim-id) (err ERR-CLAIM-NOT-FOUND))))
    (asserts! (is-eq tx-sender (get claimant claim)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get status claim) "pending") (err ERR-CLAIM_ALREADY_PROCESSED))
    (map-set claims { claim-id: claim-id } (merge claim { status: "cancelled" }))
    (try! (log-audit claim-id "claim-cancelled"))
    (ok true)
  )
)