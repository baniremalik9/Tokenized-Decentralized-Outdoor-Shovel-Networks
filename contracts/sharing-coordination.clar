;; Sharing Coordination Contract
;; Organizes shovel lending for community projects

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-UNAUTHORIZED (err u302))
(define-constant ERR-ALREADY-BORROWED (err u303))
(define-constant ERR-NOT-AVAILABLE (err u304))
(define-constant ERR-INVALID-DURATION (err u305))
(define-constant ERR-BOOKING-CONFLICT (err u306))

;; Data Variables
(define-data-var next-sharing-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var max-loan-duration uint u2592000) ;; 30 days in seconds

;; Data Maps
(define-map shared-shovels
  { sharing-id: uint }
  {
    owner: principal,
    shovel-description: (string-ascii 100),
    location: (string-ascii 50),
    available: bool,
    hourly-rate: uint,
    deposit-required: uint,
    min-duration: uint,
    max-duration: uint,
    total-loans: uint,
    rating-sum: uint,
    rating-count: uint
  }
)

(define-map shovel-bookings
  { booking-id: uint }
  {
    sharing-id: uint,
    borrower: principal,
    start-time: uint,
    end-time: uint,
    actual-return-time: (optional uint),
    total-cost: uint,
    deposit-paid: uint,
    status: (string-ascii 20),
    project-description: (string-ascii 100)
  }
)

(define-map user-ratings
  { booking-id: uint }
  {
    rated-by: principal,
    rating: uint,
    review: (string-ascii 200),
    timestamp: uint
  }
)

(define-map user-reputation
  { user: principal }
  {
    total-loans: uint,
    successful-returns: uint,
    average-rating: uint,
    total-rating-points: uint,
    rating-count: uint,
    disputes: uint
  }
)

(define-map active-loans
  { sharing-id: uint }
  {
    borrower: principal,
    booking-id: uint,
    due-date: uint
  }
)

;; Public Functions

;; Register a shovel for sharing
(define-public (register-for-sharing (shovel-description (string-ascii 100)) (location (string-ascii 50)) (hourly-rate uint) (deposit-required uint) (min-duration uint) (max-duration uint))
  (let
    (
      (sharing-id (var-get next-sharing-id))
    )
    (asserts! (and (> min-duration u0) (<= max-duration (var-get max-loan-duration))) ERR-INVALID-DURATION)
    (asserts! (<= min-duration max-duration) ERR-INVALID-DURATION)
    (map-set shared-shovels
      { sharing-id: sharing-id }
      {
        owner: tx-sender,
        shovel-description: shovel-description,
        location: location,
        available: true,
        hourly-rate: hourly-rate,
        deposit-required: deposit-required,
        min-duration: min-duration,
        max-duration: max-duration,
        total-loans: u0,
        rating-sum: u0,
        rating-count: u0
      }
    )
    (var-set next-sharing-id (+ sharing-id u1))
    (print {
      event: "shovel-registered-for-sharing",
      sharing-id: sharing-id,
      owner: tx-sender,
      location: location,
      hourly-rate: hourly-rate
    })
    (ok sharing-id)
  )
)

;; Book a shovel
(define-public (book-shovel (sharing-id uint) (start-time uint) (duration uint) (project-description (string-ascii 100)))
  (let
    (
      (shovel-data (unwrap! (map-get? shared-shovels { sharing-id: sharing-id }) ERR-NOT-FOUND))
      (booking-id (var-get next-booking-id))
      (end-time (+ start-time duration))
      (total-cost (* (get hourly-rate shovel-data) (/ duration u3600)))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (get available shovel-data) ERR-NOT-AVAILABLE)
    (asserts! (not (is-eq (get owner shovel-data) tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (and (>= duration (get min-duration shovel-data)) (<= duration (get max-duration shovel-data))) ERR-INVALID-DURATION)
    (asserts! (>= start-time current-time) ERR-INVALID-DURATION)
    (asserts! (is-none (map-get? active-loans { sharing-id: sharing-id })) ERR-ALREADY-BORROWED)

    (map-set shovel-bookings
      { booking-id: booking-id }
      {
        sharing-id: sharing-id,
        borrower: tx-sender,
        start-time: start-time,
        end-time: end-time,
        actual-return-time: none,
        total-cost: total-cost,
        deposit-paid: (get deposit-required shovel-data),
        status: "booked",
        project-description: project-description
      }
    )

    (map-set active-loans
      { sharing-id: sharing-id }
      {
        borrower: tx-sender,
        booking-id: booking-id,
        due-date: end-time
      }
    )

    (map-set shared-shovels
      { sharing-id: sharing-id }
      (merge shovel-data { available: false })
    )

    (var-set next-booking-id (+ booking-id u1))

    (print {
      event: "shovel-booked",
      booking-id: booking-id,
      sharing-id: sharing-id,
      borrower: tx-sender,
      start-time: start-time,
      end-time: end-time,
      total-cost: total-cost
    })
    (ok booking-id)
  )
)

;; Return a borrowed shovel
(define-public (return-shovel (booking-id uint))
  (let
    (
      (booking-data (unwrap! (map-get? shovel-bookings { booking-id: booking-id }) ERR-NOT-FOUND))
      (sharing-id (get sharing-id booking-data))
      (shovel-data (unwrap! (map-get? shared-shovels { sharing-id: sharing-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq (get borrower booking-data) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status booking-data) "booked") ERR-NOT-FOUND)

    (map-set shovel-bookings
      { booking-id: booking-id }
      (merge booking-data {
        actual-return-time: (some current-time),
        status: "returned"
      })
    )

    (map-delete active-loans { sharing-id: sharing-id })

    (map-set shared-shovels
      { sharing-id: sharing-id }
      (merge shovel-data {
        available: true,
        total-loans: (+ (get total-loans shovel-data) u1)
      })
    )

    ;; Update borrower reputation
    (let
      (
        (current-reputation (default-to
          { total-loans: u0, successful-returns: u0, average-rating: u0, total-rating-points: u0, rating-count: u0, disputes: u0 }
          (map-get? user-reputation { user: tx-sender })
        ))
      )
      (map-set user-reputation
        { user: tx-sender }
        (merge current-reputation {
          total-loans: (+ (get total-loans current-reputation) u1),
          successful-returns: (+ (get successful-returns current-reputation) u1)
        })
      )
    )

    (print {
      event: "shovel-returned",
      booking-id: booking-id,
      sharing-id: sharing-id,
      borrower: tx-sender,
      return-time: current-time,
      on-time: (<= current-time (get end-time booking-data))
    })
    (ok true)
  )
)

;; Rate a completed transaction
(define-public (rate-transaction (booking-id uint) (rating uint) (review (string-ascii 200)))
  (let
    (
      (booking-data (unwrap! (map-get? shovel-bookings { booking-id: booking-id }) ERR-NOT-FOUND))
      (sharing-id (get sharing-id booking-data))
      (shovel-data (unwrap! (map-get? shared-shovels { sharing-id: sharing-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-DURATION)
    (asserts! (is-eq (get status booking-data) "returned") ERR-UNAUTHORIZED)
    (asserts! (or (is-eq (get borrower booking-data) tx-sender) (is-eq (get owner shovel-data) tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (is-none (map-get? user-ratings { booking-id: booking-id })) ERR-ALREADY-BORROWED)

    (map-set user-ratings
      { booking-id: booking-id }
      {
        rated-by: tx-sender,
        rating: rating,
        review: review,
        timestamp: current-time
      }
    )

    ;; Update shovel rating
    (let
      (
        (new-rating-sum (+ (get rating-sum shovel-data) rating))
        (new-rating-count (+ (get rating-count shovel-data) u1))
      )
      (map-set shared-shovels
        { sharing-id: sharing-id }
        (merge shovel-data {
          rating-sum: new-rating-sum,
          rating-count: new-rating-count
        })
      )
    )

    (print {
      event: "transaction-rated",
      booking-id: booking-id,
      rated-by: tx-sender,
      rating: rating
    })
    (ok true)
  )
)

;; Update shovel availability
(define-public (update-availability (sharing-id uint) (available bool))
  (let
    (
      (shovel-data (unwrap! (map-get? shared-shovels { sharing-id: sharing-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq (get owner shovel-data) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-none (map-get? active-loans { sharing-id: sharing-id })) ERR-ALREADY-BORROWED)

    (map-set shared-shovels
      { sharing-id: sharing-id }
      (merge shovel-data { available: available })
    )

    (print {
      event: "availability-updated",
      sharing-id: sharing-id,
      available: available
    })
    (ok true)
  )
)

;; Read-only Functions

;; Get shared shovel information
(define-read-only (get-shared-shovel-info (sharing-id uint))
  (map-get? shared-shovels { sharing-id: sharing-id })
)

;; Get booking information
(define-read-only (get-booking-info (booking-id uint))
  (map-get? shovel-bookings { booking-id: booking-id })
)

;; Get user rating for a booking
(define-read-only (get-rating (booking-id uint))
  (map-get? user-ratings { booking-id: booking-id })
)

;; Get user reputation
(define-read-only (get-user-reputation (user principal))
  (map-get? user-reputation { user: user })
)

;; Get active loan information
(define-read-only (get-active-loan (sharing-id uint))
  (map-get? active-loans { sharing-id: sharing-id })
)

;; Check if shovel is available
(define-read-only (is-shovel-available (sharing-id uint))
  (match (map-get? shared-shovels { sharing-id: sharing-id })
    shovel-data (get available shovel-data)
    false
  )
)

;; Get shovel average rating
(define-read-only (get-shovel-rating (sharing-id uint))
  (match (map-get? shared-shovels { sharing-id: sharing-id })
    shovel-data
      (if (> (get rating-count shovel-data) u0)
        (/ (get rating-sum shovel-data) (get rating-count shovel-data))
        u0
      )
    u0
  )
)

;; Admin Functions

;; Set maximum loan duration (owner only)
(define-public (set-max-loan-duration (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set max-loan-duration new-duration)
    (ok true)
  )
)

;; Get maximum loan duration
(define-read-only (get-max-loan-duration)
  (var-get max-loan-duration)
)
