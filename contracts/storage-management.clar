;; Storage Management Contract
;; Handles seasonal shovel protection and organization

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-UNAUTHORIZED (err u402))
(define-constant ERR-STORAGE-FULL (err u403))
(define-constant ERR-INVALID-CAPACITY (err u404))
(define-constant ERR-ALREADY-STORED (err u405))

;; Data Variables
(define-data-var next-storage-id uint u1)
(define-data-var next-assignment-id uint u1)

;; Data Maps
(define-map storage-facilities
  { storage-id: uint }
  {
    manager: principal,
    location: (string-ascii 50),
    capacity: uint,
    occupied: uint,
    climate-controlled: bool,
    security-level: uint,
    monthly-rate: uint,
    facility-type: (string-ascii 30),
    operational: bool
  }
)

(define-map shovel-storage
  { assignment-id: uint }
  {
    shovel-owner: principal,
    storage-id: uint,
    shovel-description: (string-ascii 100),
    storage-start: uint,
    storage-end: (optional uint),
    protection-level: (string-ascii 20),
    monthly-cost: uint,
    special-requirements: (string-ascii 100),
    status: (string-ascii 20)
  }
)

(define-map environmental-conditions
  { storage-id: uint, date: uint }
  {
    temperature: int,
    humidity: uint,
    air-quality: uint,
    security-status: (string-ascii 20),
    last-inspection: uint,
    issues-detected: (string-ascii 100)
  }
)

(define-map storage-maintenance
  { storage-id: uint, maintenance-id: uint }
  {
    performed-by: principal,
    maintenance-type: (string-ascii 50),
    description: (string-ascii 200),
    cost: uint,
    timestamp: uint,
    next-due: uint
  }
)

(define-map facility-maintenance-count
  { storage-id: uint }
  { count: uint }
)

;; Public Functions

;; Register a storage facility
(define-public (register-storage-facility (location (string-ascii 50)) (capacity uint) (climate-controlled bool) (security-level uint) (monthly-rate uint) (facility-type (string-ascii 30)))
  (let
    (
      (storage-id (var-get next-storage-id))
    )
    (asserts! (and (> capacity u0) (<= security-level u5)) ERR-INVALID-CAPACITY)
    (map-set storage-facilities
      { storage-id: storage-id }
      {
        manager: tx-sender,
        location: location,
        capacity: capacity,
        occupied: u0,
        climate-controlled: climate-controlled,
        security-level: security-level,
        monthly-rate: monthly-rate,
        facility-type: facility-type,
        operational: true
      }
    )
    (map-set facility-maintenance-count
      { storage-id: storage-id }
      { count: u0 }
    )
    (var-set next-storage-id (+ storage-id u1))
    (print {
      event: "storage-facility-registered",
      storage-id: storage-id,
      manager: tx-sender,
      location: location,
      capacity: capacity
    })
    (ok storage-id)
  )
)

;; Store a shovel
(define-public (store-shovel (storage-id uint) (shovel-description (string-ascii 100)) (protection-level (string-ascii 20)) (special-requirements (string-ascii 100)) (duration-months uint))
  (let
    (
      (facility-data (unwrap! (map-get? storage-facilities { storage-id: storage-id }) ERR-NOT-FOUND))
      (assignment-id (var-get next-assignment-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (monthly-cost (get monthly-rate facility-data))
    )
    (asserts! (get operational facility-data) ERR-NOT-FOUND)
    (asserts! (< (get occupied facility-data) (get capacity facility-data)) ERR-STORAGE-FULL)

    (map-set shovel-storage
      { assignment-id: assignment-id }
      {
        shovel-owner: tx-sender,
        storage-id: storage-id,
        shovel-description: shovel-description,
        storage-start: current-time,
        storage-end: none,
        protection-level: protection-level,
        monthly-cost: monthly-cost,
        special-requirements: special-requirements,
        status: "stored"
      }
    )

    (map-set storage-facilities
      { storage-id: storage-id }
      (merge facility-data { occupied: (+ (get occupied facility-data) u1) })
    )

    (var-set next-assignment-id (+ assignment-id u1))

    (print {
      event: "shovel-stored",
      assignment-id: assignment-id,
      storage-id: storage-id,
      shovel-owner: tx-sender,
      protection-level: protection-level
    })
    (ok assignment-id)
  )
)

;; Retrieve a stored shovel
(define-public (retrieve-shovel (assignment-id uint))
  (let
    (
      (storage-data (unwrap! (map-get? shovel-storage { assignment-id: assignment-id }) ERR-NOT-FOUND))
      (storage-id (get storage-id storage-data))
      (facility-data (unwrap! (map-get? storage-facilities { storage-id: storage-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq (get shovel-owner storage-data) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status storage-data) "stored") ERR-NOT-FOUND)

    (map-set shovel-storage
      { assignment-id: assignment-id }
      (merge storage-data {
        storage-end: (some current-time),
        status: "retrieved"
      })
    )

    (map-set storage-facilities
      { storage-id: storage-id }
      (merge facility-data { occupied: (- (get occupied facility-data) u1) })
    )

    (print {
      event: "shovel-retrieved",
      assignment-id: assignment-id,
      storage-id: storage-id,
      shovel-owner: tx-sender,
      retrieval-time: current-time
    })
    (ok true)
  )
)

;; Record environmental conditions
(define-public (record-conditions (storage-id uint) (temperature int) (humidity uint) (air-quality uint) (security-status (string-ascii 20)) (issues-detected (string-ascii 100)))
  (let
    (
      (facility-data (unwrap! (map-get? storage-facilities { storage-id: storage-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (date-key (/ current-time u86400)) ;; Daily records
    )
    (asserts! (is-eq (get manager facility-data) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (and (<= humidity u100) (<= air-quality u100)) ERR-INVALID-CAPACITY)

    (map-set environmental-conditions
      { storage-id: storage-id, date: date-key }
      {
        temperature: temperature,
        humidity: humidity,
        air-quality: air-quality,
        security-status: security-status,
        last-inspection: current-time,
        issues-detected: issues-detected
      }
    )

    (print {
      event: "conditions-recorded",
      storage-id: storage-id,
      temperature: temperature,
      humidity: humidity,
      air-quality: air-quality,
      issues-detected: issues-detected
    })
    (ok true)
  )
)

;; Perform facility maintenance
(define-public (perform-facility-maintenance (storage-id uint) (maintenance-type (string-ascii 50)) (description (string-ascii 200)) (cost uint) (next-due-days uint))
  (let
    (
      (facility-data (unwrap! (map-get? storage-facilities { storage-id: storage-id }) ERR-NOT-FOUND))
      (maintenance-count-data (unwrap! (map-get? facility-maintenance-count { storage-id: storage-id }) ERR-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (next-due (+ current-time (* next-due-days u86400)))
    )
    (asserts! (is-eq (get manager facility-data) tx-sender) ERR-UNAUTHORIZED)

    (map-set storage-maintenance
      { storage-id: storage-id, maintenance-id: (get count maintenance-count-data) }
      {
        performed-by: tx-sender,
        maintenance-type: maintenance-type,
        description: description,
        cost: cost,
        timestamp: current-time,
        next-due: next-due
      }
    )

    (map-set facility-maintenance-count
      { storage-id: storage-id }
      { count: (+ (get count maintenance-count-data) u1) }
    )

    (print {
      event: "facility-maintenance-performed",
      storage-id: storage-id,
      maintenance-type: maintenance-type,
      cost: cost,
      next-due: next-due
    })
    (ok true)
  )
)

;; Update facility operational status
(define-public (update-facility-status (storage-id uint) (operational bool))
  (let
    (
      (facility-data (unwrap! (map-get? storage-facilities { storage-id: storage-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq (get manager facility-data) tx-sender) ERR-UNAUTHORIZED)

    (map-set storage-facilities
      { storage-id: storage-id }
      (merge facility-data { operational: operational })
    )

    (print {
      event: "facility-status-updated",
      storage-id: storage-id,
      operational: operational
    })
    (ok true)
  )
)

;; Read-only Functions

;; Get storage facility information
(define-read-only (get-facility-info (storage-id uint))
  (map-get? storage-facilities { storage-id: storage-id })
)

;; Get shovel storage assignment
(define-read-only (get-storage-assignment (assignment-id uint))
  (map-get? shovel-storage { assignment-id: assignment-id })
)

;; Get environmental conditions
(define-read-only (get-conditions (storage-id uint) (date uint))
  (map-get? environmental-conditions { storage-id: storage-id, date: date })
)

;; Get maintenance record
(define-read-only (get-maintenance-record (storage-id uint) (maintenance-id uint))
  (map-get? storage-maintenance { storage-id: storage-id, maintenance-id: maintenance-id })
)

;; Check facility availability
(define-read-only (get-facility-availability (storage-id uint))
  (match (map-get? storage-facilities { storage-id: storage-id })
    facility-data
      {
        available-spaces: (- (get capacity facility-data) (get occupied facility-data)),
        operational: (get operational facility-data)
      }
    { available-spaces: u0, operational: false }
  )
)

;; Get facility occupancy rate
(define-read-only (get-occupancy-rate (storage-id uint))
  (match (map-get? storage-facilities { storage-id: storage-id })
    facility-data
      (if (> (get capacity facility-data) u0)
        (/ (* (get occupied facility-data) u100) (get capacity facility-data))
        u0
      )
    u0
  )
)

;; Get maintenance count
(define-read-only (get-maintenance-count (storage-id uint))
  (default-to { count: u0 } (map-get? facility-maintenance-count { storage-id: storage-id }))
)

;; Admin Functions

;; Emergency facility shutdown (owner only)
(define-public (emergency-shutdown (storage-id uint))
  (let
    (
      (facility-data (unwrap! (map-get? storage-facilities { storage-id: storage-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)

    (map-set storage-facilities
      { storage-id: storage-id }
      (merge facility-data { operational: false })
    )

    (print {
      event: "emergency-shutdown",
      storage-id: storage-id,
      initiated-by: tx-sender
    })
    (ok true)
  )
)
