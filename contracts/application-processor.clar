;; Application Processing Contract
;; Manages marriage license applications and documentation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-INPUT (err u100))
(define-constant ERR-APPLICATION-EXISTS (err u107))
(define-constant ERR-APPLICATION-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))

;; Data Variables
(define-data-var application-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var next-application-id uint u1)

;; Data Maps
(define-map applications
  { application-id: uint }
  {
    applicant-1: principal,
    applicant-2: principal,
    applicant-1-name: (string-ascii 100),
    applicant-2-name: (string-ascii 100),
    application-date: uint,
    status: (string-ascii 20),
    fee-paid: bool,
    documents-verified: bool
  }
)

(define-map applicant-applications
  { applicant: principal }
  { application-ids: (list 10 uint) }
)

;; Public Functions

;; Submit a new marriage license application
(define-public (submit-application
  (applicant-2 principal)
  (applicant-1-name (string-ascii 100))
  (applicant-2-name (string-ascii 100)))
  (let
    (
      (application-id (var-get next-application-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) ERR-INVALID-INPUT))
    )
    ;; Validate inputs
    (asserts! (> (len applicant-1-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len applicant-2-name) u0) ERR-INVALID-INPUT)
    (asserts! (not (is-eq tx-sender applicant-2)) ERR-INVALID-INPUT)

    ;; Create application record
    (map-set applications
      { application-id: application-id }
      {
        applicant-1: tx-sender,
        applicant-2: applicant-2,
        applicant-1-name: applicant-1-name,
        applicant-2-name: applicant-2-name,
        application-date: current-time,
        status: "pending",
        fee-paid: false,
        documents-verified: false
      }
    )

    ;; Update applicant records
    (update-applicant-applications tx-sender application-id)
    (update-applicant-applications applicant-2 application-id)

    ;; Increment application ID
    (var-set next-application-id (+ application-id u1))

    (ok application-id)
  )
)

;; Pay application fee
(define-public (pay-application-fee (application-id uint))
  (let
    (
      (application (unwrap! (map-get? applications { application-id: application-id }) ERR-APPLICATION-NOT-FOUND))
      (fee-amount (var-get application-fee))
    )
    ;; Verify applicant
    (asserts! (or (is-eq tx-sender (get applicant-1 application))
                  (is-eq tx-sender (get applicant-2 application))) ERR-UNAUTHORIZED)

    ;; Verify fee not already paid
    (asserts! (not (get fee-paid application)) ERR-INVALID-INPUT)

    ;; Transfer fee to contract
    (try! (stx-transfer? fee-amount tx-sender (as-contract tx-sender)))

    ;; Update application
    (map-set applications
      { application-id: application-id }
      (merge application { fee-paid: true })
    )

    (ok true)
  )
)

;; Verify documents (admin only)
(define-public (verify-documents (application-id uint))
  (let
    (
      (application (unwrap! (map-get? applications { application-id: application-id }) ERR-APPLICATION-NOT-FOUND))
    )
    ;; Only contract owner can verify documents
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)

    ;; Update application
    (map-set applications
      { application-id: application-id }
      (merge application {
        documents-verified: true,
        status: "approved"
      })
    )

    (ok true)
  )
)

;; Update application status (admin only)
(define-public (update-application-status (application-id uint) (new-status (string-ascii 20)))
  (let
    (
      (application (unwrap! (map-get? applications { application-id: application-id }) ERR-APPLICATION-NOT-FOUND))
    )
    ;; Only contract owner can update status
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)

    ;; Validate status
    (asserts! (> (len new-status) u0) ERR-INVALID-INPUT)

    ;; Update application
    (map-set applications
      { application-id: application-id }
      (merge application { status: new-status })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get application details
(define-read-only (get-application (application-id uint))
  (map-get? applications { application-id: application-id })
)

;; Get applications for an applicant
(define-read-only (get-applicant-applications (applicant principal))
  (map-get? applicant-applications { applicant: applicant })
)

;; Check if application is ready for ceremony
(define-read-only (is-application-ready (application-id uint))
  (match (map-get? applications { application-id: application-id })
    application (and (get fee-paid application)
                     (get documents-verified application)
                     (is-eq (get status application) "approved"))
    false
  )
)

;; Get current application fee
(define-read-only (get-application-fee)
  (var-get application-fee)
)

;; Private Functions

;; Update applicant application list
(define-private (update-applicant-applications (applicant principal) (application-id uint))
  (let
    (
      (current-apps (default-to { application-ids: (list) }
                                (map-get? applicant-applications { applicant: applicant })))
      (updated-list (unwrap! (as-max-len? (append (get application-ids current-apps) application-id) u10) ERR-INVALID-INPUT))
    )
    (map-set applicant-applications
      { applicant: applicant }
      { application-ids: updated-list }
    )
    (ok true)
  )
)

;; Admin Functions

;; Set application fee (admin only)
(define-public (set-application-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)
    (var-set application-fee new-fee)
    (ok true)
  )
)
