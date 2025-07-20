;; Ceremony Scheduling Contract
;; Coordinates wedding ceremony appointments at city hall

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-INPUT (err u100))
(define-constant ERR-SCHEDULE-CONFLICT (err u104))
(define-constant ERR-BOOKING-NOT-FOUND (err u102))
(define-constant ERR-PREREQUISITES-NOT-MET (err u106))

;; Data Variables
(define-data-var next-booking-id uint u1)
(define-data-var ceremony-duration uint u3600) ;; 1 hour in seconds
(define-data-var max-daily-ceremonies uint u10)

;; Data Maps
(define-map ceremony-bookings
  { booking-id: uint }
  {
    application-id: uint,
    applicant-1: principal,
    applicant-2: principal,
    ceremony-date: uint,
    ceremony-time: uint,
    venue: (string-ascii 50),
    officiant: (optional principal),
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map daily-ceremony-count
  { date: uint }
  { count: uint }
)

(define-map time-slot-bookings
  { date: uint, time-slot: uint }
  { booking-id: uint }
)

;; Public Functions

;; Schedule a ceremony
(define-public (schedule-ceremony
  (application-id uint)
  (ceremony-date uint)
  (ceremony-time uint)
  (venue (string-ascii 50)))
  (let
    (
      (booking-id (var-get next-booking-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) ERR-INVALID-INPUT))
      (time-slot (calculate-time-slot ceremony-time))
    )
    ;; Validate inputs
    (asserts! (> ceremony-date current-time) ERR-INVALID-INPUT)
    (asserts! (> (len venue) u0) ERR-INVALID-INPUT)

    ;; Check if application is ready (would need to call application processor)
    ;; For now, we'll assume it's valid

    ;; Check for scheduling conflicts
    (asserts! (is-none (map-get? time-slot-bookings { date: ceremony-date, time-slot: time-slot })) ERR-SCHEDULE-CONFLICT)

    ;; Check daily ceremony limit
    (let
      (
        (daily-count (default-to { count: u0 } (map-get? daily-ceremony-count { date: ceremony-date })))
      )
      (asserts! (< (get count daily-count) (var-get max-daily-ceremonies)) ERR-SCHEDULE-CONFLICT)

      ;; Update daily count
      (map-set daily-ceremony-count
        { date: ceremony-date }
        { count: (+ (get count daily-count) u1) }
      )
    )

    ;; Reserve time slot
    (map-set time-slot-bookings
      { date: ceremony-date, time-slot: time-slot }
      { booking-id: booking-id }
    )

    ;; Create booking record
    (map-set ceremony-bookings
      { booking-id: booking-id }
      {
        application-id: application-id,
        applicant-1: tx-sender,
        applicant-2: tx-sender, ;; Would get from application
        ceremony-date: ceremony-date,
        ceremony-time: ceremony-time,
        venue: venue,
        officiant: none,
        status: "scheduled",
        created-at: current-time
      }
    )

    ;; Increment booking ID
    (var-set next-booking-id (+ booking-id u1))

    (ok booking-id)
  )
)

;; Assign officiant to ceremony
(define-public (assign-officiant (booking-id uint) (officiant principal))
  (let
    (
      (booking (unwrap! (map-get? ceremony-bookings { booking-id: booking-id }) ERR-BOOKING-NOT-FOUND))
    )
    ;; Only contract owner or applicants can assign officiant
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (is-eq tx-sender (get applicant-1 booking))
                  (is-eq tx-sender (get applicant-2 booking))) ERR-UNAUTHORIZED)

    ;; Update booking with officiant
    (map-set ceremony-bookings
      { booking-id: booking-id }
      (merge booking {
        officiant: (some officiant),
        status: "confirmed"
      })
    )

    (ok true)
  )
)

;; Complete ceremony
(define-public (complete-ceremony (booking-id uint))
  (let
    (
      (booking (unwrap! (map-get? ceremony-bookings { booking-id: booking-id }) ERR-BOOKING-NOT-FOUND))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) ERR-INVALID-INPUT))
    )
    ;; Only officiant can complete ceremony
    (asserts! (is-some (get officiant booking)) ERR-PREREQUISITES-NOT-MET)
    (asserts! (is-eq tx-sender (unwrap! (get officiant booking) ERR-PREREQUISITES-NOT-MET)) ERR-UNAUTHORIZED)

    ;; Verify ceremony time has passed
    (asserts! (>= current-time (get ceremony-time booking)) ERR-INVALID-INPUT)

    ;; Update booking status
    (map-set ceremony-bookings
      { booking-id: booking-id }
      (merge booking { status: "completed" })
    )

    (ok true)
  )
)

;; Cancel ceremony
(define-public (cancel-ceremony (booking-id uint))
  (let
    (
      (booking (unwrap! (map-get? ceremony-bookings { booking-id: booking-id }) ERR-BOOKING-NOT-FOUND))
      (time-slot (calculate-time-slot (get ceremony-time booking)))
    )
    ;; Only applicants or admin can cancel
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (is-eq tx-sender (get applicant-1 booking))
                  (is-eq tx-sender (get applicant-2 booking))) ERR-UNAUTHORIZED)

    ;; Free up the time slot
    (map-delete time-slot-bookings { date: (get ceremony-date booking), time-slot: time-slot })

    ;; Update daily count
    (let
      (
        (daily-count (default-to { count: u0 } (map-get? daily-ceremony-count { date: (get ceremony-date booking) })))
      )
      (map-set daily-ceremony-count
        { date: (get ceremony-date booking) }
        { count: (if (> (get count daily-count) u0) (- (get count daily-count) u1) u0) }
      )
    )

    ;; Update booking status
    (map-set ceremony-bookings
      { booking-id: booking-id }
      (merge booking { status: "cancelled" })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get ceremony booking details
(define-read-only (get-ceremony-booking (booking-id uint))
  (map-get? ceremony-bookings { booking-id: booking-id })
)

;; Check if time slot is available
(define-read-only (is-time-slot-available (date uint) (time uint))
  (let
    (
      (time-slot (calculate-time-slot time))
    )
    (is-none (map-get? time-slot-bookings { date: date, time-slot: time-slot }))
  )
)

;; Get daily ceremony count
(define-read-only (get-daily-ceremony-count (date uint))
  (default-to { count: u0 } (map-get? daily-ceremony-count { date: date }))
)

;; Get available time slots for a date
(define-read-only (get-available-slots (date uint))
  (let
    (
      (daily-count (get count (get-daily-ceremony-count date)))
    )
    (- (var-get max-daily-ceremonies) daily-count)
  )
)

;; Private Functions

;; Calculate time slot (rounds to nearest hour)
(define-private (calculate-time-slot (time uint))
  (/ time u3600)
)

;; Admin Functions

;; Set ceremony duration
(define-public (set-ceremony-duration (duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> duration u0) ERR-INVALID-INPUT)
    (var-set ceremony-duration duration)
    (ok true)
  )
)

;; Set max daily ceremonies
(define-public (set-max-daily-ceremonies (max-ceremonies uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> max-ceremonies u0) ERR-INVALID-INPUT)
    (var-set max-daily-ceremonies max-ceremonies)
    (ok true)
  )
)
