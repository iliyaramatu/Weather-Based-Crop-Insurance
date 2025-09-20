(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_POLICY_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_POLICY_EXPIRED (err u103))
(define-constant ERR_ALREADY_CLAIMED (err u104))
(define-constant ERR_CONDITIONS_NOT_MET (err u105))
(define-constant ERR_INVALID_ORACLE (err u106))
(define-constant ERR_POLICY_ACTIVE (err u107))
(define-constant ERR_INVALID_DISCOUNT (err u108))

(define-data-var next-policy-id uint u1)
(define-data-var total-premiums uint u0)
(define-data-var total-payouts uint u0)
(define-data-var oracle-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var total-farmers-with-discounts uint u0)

(define-map policies
  { policy-id: uint }
  {
    farmer: principal,
    coverage-amount: uint,
    premium: uint,
    crop-type: (string-ascii 50),
    location: (string-ascii 100),
    planting-date: uint,
    harvest-date: uint,
    rainfall-threshold-min: uint,
    rainfall-threshold-max: uint,
    temperature-threshold-min: uint,
    temperature-threshold-max: uint,
    claimed: bool,
    active: bool
  }
)

(define-map weather-data
  { location: (string-ascii 100), date: uint }
  {
    rainfall: uint,
    temperature: uint,
    verified: bool,
    oracle: principal
  }
)

(define-map farmer-policies
  { farmer: principal }
  { policy-ids: (list 50 uint) }
)

(define-map oracle-registry
  { oracle: principal }
  { authorized: bool, reputation: uint }
)

;; Farmer loyalty tracking for premium discounts
(define-map farmer-loyalty
  { farmer: principal }
  { 
    consecutive-seasons: uint,
    total-policies: uint,
    total-claims: uint,
    last-policy-season: uint,
    discount-percentage: uint,
    loyalty-tier: (string-ascii 20)
  }
)

(define-public (initialize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set oracle-registry { oracle: oracle } { authorized: true, reputation: u100 })
    (var-set oracle-address oracle)
    (ok true)
  )
)

(define-public (purchase-policy 
  (coverage-amount uint)
  (crop-type (string-ascii 50))
  (location (string-ascii 100))
  (planting-date uint)
  (harvest-date uint)
  (rainfall-min uint)
  (rainfall-max uint)
  (temp-min uint)
  (temp-max uint)
)
  (let
    (
      (policy-id (var-get next-policy-id))
      (base-premium (calculate-premium coverage-amount (- harvest-date planting-date)))
      (discount-percentage (get-farmer-discount-percentage tx-sender))
      (premium (apply-premium-discount base-premium discount-percentage))
      (current-policies (default-to { policy-ids: (list) } (map-get? farmer-policies { farmer: tx-sender })))
      (current-season (/ stacks-block-height u2016)) ;; Approximate season calculation
    )
    (asserts! (>= (stx-get-balance tx-sender) premium) ERR_INSUFFICIENT_FUNDS)
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set policies
      { policy-id: policy-id }
      {
        farmer: tx-sender,
        coverage-amount: coverage-amount,
        premium: premium,
        crop-type: crop-type,
        location: location,
        planting-date: planting-date,
        harvest-date: harvest-date,
        rainfall-threshold-min: rainfall-min,
        rainfall-threshold-max: rainfall-max,
        temperature-threshold-min: temp-min,
        temperature-threshold-max: temp-max,
        claimed: false,
        active: true
      }
    )
    
    (map-set farmer-policies 
      { farmer: tx-sender } 
      { policy-ids: (unwrap-panic (as-max-len? (append (get policy-ids current-policies) policy-id) u50)) }
    )
    
    (var-set next-policy-id (+ policy-id u1))
    (var-set total-premiums (+ (var-get total-premiums) premium))
    (unwrap-panic (update-farmer-loyalty tx-sender current-season false))
    (ok policy-id)
  )
)

(define-public (submit-weather-data 
  (location (string-ascii 100))
  (date uint)
  (rainfall uint)
  (temperature uint)
)
  (let
    ((oracle-info (default-to { authorized: false, reputation: u0 } 
                              (map-get? oracle-registry { oracle: tx-sender }))))
    (asserts! (get authorized oracle-info) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get reputation oracle-info) u50) ERR_INVALID_ORACLE)
    
    (map-set weather-data
      { location: location, date: date }
      {
        rainfall: rainfall,
        temperature: temperature,
        verified: true,
        oracle: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (file-claim (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (current-block burn-block-height)
    )
    (asserts! (is-eq (get farmer policy) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get active policy) ERR_POLICY_EXPIRED)
    (asserts! (not (get claimed policy)) ERR_ALREADY_CLAIMED)
    (asserts! (>= current-block (get harvest-date policy)) ERR_POLICY_ACTIVE)
    
    (let
      (
        (weather-conditions (check-weather-conditions policy))
        (payout-amount (if (unwrap! weather-conditions ERR_CONDITIONS_NOT_MET)
                          (get coverage-amount policy)
                          u0))
      )
      (if (> payout-amount u0)
        (begin
          (try! (as-contract (stx-transfer? payout-amount tx-sender (get farmer policy))))
          (map-set policies
            { policy-id: policy-id }
            (merge policy { claimed: true, active: false })
          )
          (var-set total-payouts (+ (var-get total-payouts) payout-amount))
          (unwrap-panic (update-farmer-loyalty (get farmer policy) (/ stacks-block-height u2016) true))
          (ok payout-amount)
        )
        ERR_CONDITIONS_NOT_MET
      )
    )
  )
)

(define-public (cancel-policy (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (current-block burn-block-height)
    )
    (asserts! (is-eq (get farmer policy) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get active policy) ERR_POLICY_EXPIRED)
    (asserts! (< current-block (get planting-date policy)) ERR_POLICY_ACTIVE)
    
    (let
      ((refund-amount (/ (* (get premium policy) u80) u100)))
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get farmer policy))))
      (map-set policies
        { policy-id: policy-id }
        (merge policy { active: false })
      )
      (ok refund-amount)
    )
  )
)

(define-public (update-oracle-reputation (oracle principal) (new-reputation uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-reputation u100) (err u109))
    (map-set oracle-registry
      { oracle: oracle }
      (merge (default-to { authorized: false, reputation: u0 } 
                         (map-get? oracle-registry { oracle: oracle }))
             { reputation: new-reputation })
    )
    (ok true)
  )
)

;; Update farmer loyalty stats and calculate discount eligibility
(define-public (update-farmer-loyalty (farmer principal) (season uint) (filed-claim bool))
  (let
    (
      (current-loyalty (default-to 
        { 
          consecutive-seasons: u0,
          total-policies: u0,
          total-claims: u0,
          last-policy-season: u0,
          discount-percentage: u0,
          loyalty-tier: "bronze"
        } 
        (map-get? farmer-loyalty { farmer: farmer })))
      (is-consecutive (or 
        (is-eq (get last-policy-season current-loyalty) u0)
        (is-eq season (+ (get last-policy-season current-loyalty) u1))))
      (new-consecutive-seasons (if is-consecutive 
        (+ (get consecutive-seasons current-loyalty) u1)
        u1))
      (new-total-policies (+ (get total-policies current-loyalty) u1))
      (new-total-claims (if filed-claim 
        (+ (get total-claims current-loyalty) u1)
        (get total-claims current-loyalty)))
      (new-discount-percentage (calculate-loyalty-discount new-consecutive-seasons new-total-claims))
      (new-loyalty-tier (get-loyalty-tier new-consecutive-seasons))
      (old-discount (get discount-percentage current-loyalty))
    )
    ;; Update discount counter if farmer gets their first discount
    (if (and (is-eq old-discount u0) (> new-discount-percentage u0))
      (var-set total-farmers-with-discounts (+ (var-get total-farmers-with-discounts) u1))
      true
    )
    (map-set farmer-loyalty
      { farmer: farmer }
      {
        consecutive-seasons: new-consecutive-seasons,
        total-policies: new-total-policies,
        total-claims: new-total-claims,
        last-policy-season: season,
        discount-percentage: new-discount-percentage,
        loyalty-tier: new-loyalty-tier
      }
    )
    (ok true)
  )
)

;; Calculate discount percentage based on consecutive seasons without claims
(define-read-only (calculate-loyalty-discount (consecutive-seasons uint) (total-claims uint))
  (if (is-eq total-claims u0)
    (if (>= consecutive-seasons u8)
      u20  ;; 20% discount for 8+ seasons
      (if (>= consecutive-seasons u5)
        u15  ;; 15% discount for 5-7 seasons
        (if (>= consecutive-seasons u3)
          u10  ;; 10% discount for 3-4 seasons
          (if (>= consecutive-seasons u2)
            u5   ;; 5% discount for 2+ seasons
            u0   ;; No discount for first season
          )
        )
      )
    )
    u0  ;; No discount if farmer has claims
  )
)

;; Get loyalty tier based on consecutive seasons
(define-read-only (get-loyalty-tier (consecutive-seasons uint))
  (if (>= consecutive-seasons u8)
    "platinum"
    (if (>= consecutive-seasons u5)
      "gold"
      (if (>= consecutive-seasons u3)
        "silver"
        "bronze"
      )
    )
  )
)

;; Apply discount to premium
(define-read-only (apply-premium-discount (base-premium uint) (discount-percentage uint))
  (let
    ((discount-amount (/ (* base-premium discount-percentage) u100)))
    (- base-premium discount-amount)
  )
)

;; Get farmer's current discount percentage
(define-read-only (get-farmer-discount-percentage (farmer principal))
  (let
    ((loyalty-info (map-get? farmer-loyalty { farmer: farmer })))
    (match loyalty-info
      info (get discount-percentage info)
      u0
    )
  )
)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-farmer-policies (farmer principal))
  (map-get? farmer-policies { farmer: farmer })
)

(define-read-only (get-weather-data (location (string-ascii 100)) (date uint))
  (map-get? weather-data { location: location, date: date })
)

(define-read-only (get-contract-stats)
  {
    total-policies: (- (var-get next-policy-id) u1),
    total-premiums: (var-get total-premiums),
    total-payouts: (var-get total-payouts),
    contract-balance: (stx-get-balance (as-contract tx-sender)),
    farmers-with-discounts: (var-get total-farmers-with-discounts)
  }
)

;; Get farmer loyalty information
(define-read-only (get-farmer-loyalty-info (farmer principal))
  (map-get? farmer-loyalty { farmer: farmer })
)

;; Get all farmers eligible for discounts (owner only for analytics)
(define-read-only (get-loyalty-statistics)
  {
    total-farmers-with-discounts: (var-get total-farmers-with-discounts),
    loyalty-program-active: true
  }
)

(define-read-only (calculate-premium (coverage-amount uint) (policy-duration uint))
  (let
    (
      (base-rate u5)
      (duration-factor (if (> policy-duration u180) u150 u100))
      (coverage-factor (/ coverage-amount u10000))
    )
    (/ (* (* coverage-amount base-rate) duration-factor) (* u100 u100))
  )
)

(define-read-only (check-weather-conditions (policy { 
  farmer: principal,
  coverage-amount: uint,
  premium: uint,
  crop-type: (string-ascii 50),
  location: (string-ascii 100),
  planting-date: uint,
  harvest-date: uint,
  rainfall-threshold-min: uint,
  rainfall-threshold-max: uint,
  temperature-threshold-min: uint,
  temperature-threshold-max: uint,
  claimed: bool,
  active: bool
}))
  (let
    (
      (growing-season-start (get planting-date policy))
      (growing-season-end (get harvest-date policy))
      (location (get location policy))
    )
    (ok (check-weather-data-range 
          location 
          growing-season-start 
          growing-season-end
          (get rainfall-threshold-min policy)
          (get rainfall-threshold-max policy)
          (get temperature-threshold-min policy)
          (get temperature-threshold-max policy)
        ))
  )
)

(define-private (check-weather-data-range 
  (location (string-ascii 100))
  (start-date uint)
  (end-date uint)
  (rainfall-min uint)
  (rainfall-max uint)
  (temp-min uint)
  (temp-max uint)
)
  (let
    (
      (sample-date (+ start-date (/ (- end-date start-date) u2)))
      (weather-info (map-get? weather-data { location: location, date: sample-date }))
    )
    (match weather-info
      weather-record
        (and 
          (get verified weather-record)
          (or 
            (< (get rainfall weather-record) rainfall-min)
            (> (get rainfall weather-record) rainfall-max)
            (< (get temperature weather-record) temp-min)
            (> (get temperature weather-record) temp-max)
          )
        )
      false
    )
  )
)

(define-read-only (get-oracle-info (oracle principal))
  (map-get? oracle-registry { oracle: oracle })
)

(define-public (fund-contract (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok amount)
  )
)
