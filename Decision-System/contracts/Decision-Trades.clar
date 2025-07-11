;; Decentralized Policy Outcome Prediction Market Smart Contract
;; A comprehensive prediction market platform for forecasting policy outcomes,
;; enabling users to create markets, place bets on policy decisions, resolve outcomes,
;; and claim rewards. Features automatic market expiration, bet refunds, and
;; administrative controls for platform governance.

;; ERROR CONSTANTS

(define-constant ERR-INVALID-MARKET-CLOSING-BLOCK-HEIGHT (err u1))
(define-constant ERR-MARKET-BETTING-PERIOD-ENDED (err u2))
(define-constant ERR-MARKET-OUTCOME-ALREADY-DETERMINED (err u3))
(define-constant ERR-INVALID-BET-CONFIGURATION (err u4))
(define-constant ERR-MARKET-IDENTIFIER-NOT-FOUND (err u5))
(define-constant ERR-INSUFFICIENT-ACCOUNT-BALANCE (err u6))
(define-constant ERR-MARKET-STILL-ACCEPTING-BETS (err u7))
(define-constant ERR-USER-BET-NOT-FOUND (err u8))
(define-constant ERR-MARKET-OUTCOME-NOT-RESOLVED (err u9))
(define-constant ERR-PREDICTION-DOES-NOT-MATCH-OUTCOME (err u10))
(define-constant ERR-MARKET-PAST-EXPIRATION-DATE (err u11))
(define-constant ERR-MARKET-NOT-YET-EXPIRED (err u12))
(define-constant ERR-UNAUTHORIZED-PLATFORM-ACCESS (err u13))
(define-constant ERR-BET-AMOUNT-BELOW-MINIMUM (err u14))
(define-constant ERR-BET-AMOUNT-EXCEEDS-MAXIMUM (err u15))
(define-constant ERR-INVALID-FUNCTION-PARAMETER (err u16))
(define-constant ERR-INVALID-MARKET-IDENTIFIER (err u17))

;; PLATFORM CONFIGURATION CONSTANTS

(define-constant maximum-market-closing-delay-blocks u52560) ;; ~1 year in blocks
(define-constant minimum-market-closing-delay-blocks u144)   ;; ~1 day in blocks  
(define-constant maximum-market-expiration-window-blocks u105120) ;; ~2 years in blocks
(define-constant minimum-market-description-length u10)

;; PLATFORM STATE VARIABLES

(define-data-var platform-service-name (string-ascii 70) "PolicyOracle: Decentralized Policy Outcome Prediction Platform")
(define-data-var next-available-market-identifier uint u1)
(define-data-var platform-governance-authority principal tx-sender)

;; CONFIGURABLE PLATFORM PARAMETERS

(define-data-var default-market-expiration-period-blocks uint u10000)
(define-data-var minimum-allowed-bet-amount uint u10)
(define-data-var maximum-allowed-bet-amount uint u1000000)

;; DATA STORAGE STRUCTURES

(define-map policy-prediction-markets
  { market-identifier: uint }
  {
    market-description-text: (string-ascii 256),
    resolved-outcome-result: (optional bool),
    betting-closes-at-block: uint,
    market-expires-at-block: uint,
    market-creator-address: principal
  }
)

(define-map participant-betting-records
  { market-identifier: uint, participant-address: principal }
  { wagered-amount: uint, predicted-outcome-value: bool }
)

;; VALIDATION HELPER FUNCTIONS

(define-private (is-valid-market-identifier? (market-id uint))
  (< market-id (var-get next-available-market-identifier))
)

(define-private (has-market-expired? (market-id uint))
  (let ((market-information (unwrap! (map-get? policy-prediction-markets { market-identifier: market-id }) false)))
    (>= block-height (get market-expires-at-block market-information))
  )
)

(define-private (is-description-length-valid? (description-text (string-ascii 256)))
  (and 
    (>= (len description-text) minimum-market-description-length)
    (<= (len description-text) u256)
  )
)

(define-private (is-closing-block-height-valid? (closing-block-height uint))
  (let 
    (
      (blocks-until-closing (- closing-block-height block-height))
    )
    (and
      (>= blocks-until-closing minimum-market-closing-delay-blocks)
      (<= blocks-until-closing maximum-market-closing-delay-blocks)
    )
  )
)

(define-private (is-expiration-block-height-valid? (closing-block uint) (expiration-block uint))
  (let
    (
      (expiration-window-size (- expiration-block closing-block))
    )
    (and
      (> expiration-block closing-block)
      (<= expiration-window-size maximum-market-expiration-window-blocks)
    )
  )
)

(define-private (is-bet-amount-within-limits? (bet-amount uint))
  (and
    (>= bet-amount (var-get minimum-allowed-bet-amount))
    (<= bet-amount (var-get maximum-allowed-bet-amount))
  )
)

(define-private (verify-market-exists-for-deletion (market-id uint))
  (match (map-get? policy-prediction-markets { market-identifier: market-id })
    market-data true
    false)
)

(define-private (verify-user-bet-exists-for-deletion (market-id uint) (user-address principal))
  (match (map-get? participant-betting-records { market-identifier: market-id, participant-address: user-address })
    bet-data true
    false)
)

;; MARKET CREATION AND MANAGEMENT

(define-public (create-new-policy-prediction-market (description-text (string-ascii 256)) (betting-closes-at-block uint))
  (let
    (
      (new-market-identifier (var-get next-available-market-identifier))
      (calculated-expiration-block (+ betting-closes-at-block (var-get default-market-expiration-period-blocks)))
    )
    ;; Validate all input parameters
    (asserts! (is-description-length-valid? description-text) ERR-INVALID-FUNCTION-PARAMETER)
    (asserts! (is-closing-block-height-valid? betting-closes-at-block) ERR-INVALID-MARKET-CLOSING-BLOCK-HEIGHT)
    (asserts! (is-expiration-block-height-valid? betting-closes-at-block calculated-expiration-block) ERR-INVALID-FUNCTION-PARAMETER)
    
    ;; Create the new market record
    (map-set policy-prediction-markets
      { market-identifier: new-market-identifier }
      {
        market-description-text: description-text,
        resolved-outcome-result: none,
        betting-closes-at-block: betting-closes-at-block,
        market-expires-at-block: calculated-expiration-block,
        market-creator-address: tx-sender
      }
    )
    
    ;; Increment market counter for next market
    (var-set next-available-market-identifier (+ new-market-identifier u1))
    (ok new-market-identifier)
  )
)

;; BETTING FUNCTIONALITY

(define-public (place-outcome-prediction-bet (market-id uint) (predicted-outcome-value bool) (bet-amount uint))
  (let
    (
      (existing-bet-record (default-to { wagered-amount: u0, predicted-outcome-value: false } 
                           (map-get? participant-betting-records { market-identifier: market-id, participant-address: tx-sender })))
    )
    ;; Validate basic parameters
    (asserts! (is-valid-market-identifier? market-id) ERR-MARKET-IDENTIFIER-NOT-FOUND)
    (asserts! (is-bet-amount-within-limits? bet-amount) ERR-INVALID-BET-CONFIGURATION)
    
    (let
      (
        (market-information (unwrap! (map-get? policy-prediction-markets { market-identifier: market-id }) ERR-MARKET-IDENTIFIER-NOT-FOUND))
        (total-wagered-amount (+ bet-amount (get wagered-amount existing-bet-record)))
      )
      ;; Validate market state and betting limits
      (asserts! (<= total-wagered-amount (var-get maximum-allowed-bet-amount)) ERR-BET-AMOUNT-EXCEEDS-MAXIMUM)
      (asserts! (< block-height (get betting-closes-at-block market-information)) ERR-MARKET-BETTING-PERIOD-ENDED)
      (asserts! (is-none (get resolved-outcome-result market-information)) ERR-MARKET-OUTCOME-ALREADY-DETERMINED)
      (asserts! (>= (stx-get-balance tx-sender) bet-amount) ERR-INSUFFICIENT-ACCOUNT-BALANCE)
      
      ;; Update betting record
      (map-set participant-betting-records
        { market-identifier: market-id, participant-address: tx-sender }
        { wagered-amount: total-wagered-amount, predicted-outcome-value: predicted-outcome-value }
      )
      
      ;; Transfer bet amount to contract
      (stx-transfer? bet-amount tx-sender (as-contract tx-sender))
    )
  )
)

;; MARKET RESOLUTION FUNCTIONALITY

(define-public (resolve-policy-market-outcome (market-id uint) (actual-outcome-result bool))
  (let 
    (
      (market-information (unwrap! (map-get? policy-prediction-markets { market-identifier: market-id }) ERR-MARKET-IDENTIFIER-NOT-FOUND))
    )
    ;; Validate market resolution permissions and state
    (asserts! (is-valid-market-identifier? market-id) ERR-INVALID-MARKET-IDENTIFIER)
    (asserts! (>= block-height (get betting-closes-at-block market-information)) ERR-MARKET-STILL-ACCEPTING-BETS)
    (asserts! (is-none (get resolved-outcome-result market-information)) ERR-MARKET-OUTCOME-ALREADY-DETERMINED)
    (asserts! (not (has-market-expired? market-id)) ERR-MARKET-PAST-EXPIRATION-DATE)
    (asserts! (or 
                (is-eq tx-sender (get market-creator-address market-information))
                (is-eq tx-sender (var-get platform-governance-authority))
              ) ERR-UNAUTHORIZED-PLATFORM-ACCESS)
    
    ;; Update market with resolved outcome
    (map-set policy-prediction-markets
      { market-identifier: market-id }
      (merge market-information { resolved-outcome-result: (some actual-outcome-result) })
    )
    (ok true)
  )
)

;; REWARD CLAIMING FUNCTIONALITY

(define-public (claim-prediction-reward (market-id uint))
  (begin
    ;; Validate market identifier first
    (asserts! (is-valid-market-identifier? market-id) ERR-INVALID-MARKET-IDENTIFIER)
    
    (let
      (
        (market-information (unwrap! (map-get? policy-prediction-markets { market-identifier: market-id }) ERR-MARKET-IDENTIFIER-NOT-FOUND))
        (participant-bet-record (unwrap! (map-get? participant-betting-records { market-identifier: market-id, participant-address: tx-sender }) ERR-USER-BET-NOT-FOUND))
        (actual-market-outcome (unwrap! (get resolved-outcome-result market-information) ERR-MARKET-OUTCOME-NOT-RESOLVED))
      )
      ;; Verify correct prediction
      (asserts! (is-eq (get predicted-outcome-value participant-bet-record) actual-market-outcome) ERR-PREDICTION-DOES-NOT-MATCH-OUTCOME)
      
      ;; Verify bet record exists before processing
      (asserts! (verify-user-bet-exists-for-deletion market-id tx-sender) ERR-USER-BET-NOT-FOUND)
      
      ;; Process reward payment
      (let ((reward-payout-amount (get wagered-amount participant-bet-record)))
        ;; Remove bet record to prevent double-claiming
        (map-delete participant-betting-records { market-identifier: market-id, participant-address: tx-sender })
        ;; Transfer reward to participant
        (as-contract (stx-transfer? reward-payout-amount tx-sender tx-sender))
      )
    )
  )
)

;; MARKET CLEANUP AND REFUND FUNCTIONALITY

(define-public (claim-refund-from-expired-market (market-id uint))
  (begin
    ;; Validate market identifier first
    (asserts! (is-valid-market-identifier? market-id) ERR-INVALID-MARKET-IDENTIFIER)
    
    (let
      (
        (market-information (unwrap! (map-get? policy-prediction-markets { market-identifier: market-id }) ERR-MARKET-IDENTIFIER-NOT-FOUND))
        (participant-bet-record (unwrap! (map-get? participant-betting-records { market-identifier: market-id, participant-address: tx-sender }) ERR-USER-BET-NOT-FOUND))
      )
      ;; Validate market expiration and unresolved state
      (asserts! (>= block-height (get market-expires-at-block market-information)) ERR-MARKET-NOT-YET-EXPIRED)
      (asserts! (is-none (get resolved-outcome-result market-information)) ERR-MARKET-OUTCOME-ALREADY-DETERMINED)
      
      ;; Verify bet record exists before processing
      (asserts! (verify-user-bet-exists-for-deletion market-id tx-sender) ERR-USER-BET-NOT-FOUND)
      
      ;; Process refund
      (let ((refund-amount (get wagered-amount participant-bet-record)))
        ;; Remove bet record
        (map-delete participant-betting-records { market-identifier: market-id, participant-address: tx-sender })
        ;; Return funds to participant
        (as-contract (stx-transfer? refund-amount tx-sender tx-sender))
      )
    )
  )
)

(define-public (remove-expired-market-data (market-id uint))
  (begin
    ;; Validate market identifier first
    (asserts! (is-valid-market-identifier? market-id) ERR-INVALID-MARKET-IDENTIFIER)
    
    (let
      (
        (market-information (unwrap! (map-get? policy-prediction-markets { market-identifier: market-id }) ERR-MARKET-IDENTIFIER-NOT-FOUND))
      )
      ;; Validate expiration and authorization
      (asserts! (>= block-height (get market-expires-at-block market-information)) ERR-MARKET-NOT-YET-EXPIRED)
      (asserts! (or 
                  (is-eq tx-sender (get market-creator-address market-information))
                  (is-eq tx-sender (var-get platform-governance-authority))
                ) ERR-UNAUTHORIZED-PLATFORM-ACCESS)
      
      ;; Verify market exists before deletion
      (asserts! (verify-market-exists-for-deletion market-id) ERR-MARKET-IDENTIFIER-NOT-FOUND)
      
      ;; Remove market data
      (map-delete policy-prediction-markets { market-identifier: market-id })
      (ok true)
    )
  )
)

;; PLATFORM CONFIGURATION MANAGEMENT

(define-public (update-market-expiration-period (new-expiration-period-blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-governance-authority)) ERR-UNAUTHORIZED-PLATFORM-ACCESS)
    (asserts! (and 
      (>= new-expiration-period-blocks u1000)  ;; Minimum ~1 day in blocks
      (<= new-expiration-period-blocks u52560) ;; Maximum ~1 year in blocks
    ) ERR-INVALID-FUNCTION-PARAMETER)
    (ok (var-set default-market-expiration-period-blocks new-expiration-period-blocks))
  )
)

(define-public (update-minimum-bet-threshold (new-minimum-bet-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-governance-authority)) ERR-UNAUTHORIZED-PLATFORM-ACCESS)
    (asserts! (and 
      (>= new-minimum-bet-amount u1)
      (< new-minimum-bet-amount (var-get maximum-allowed-bet-amount))
      (<= new-minimum-bet-amount u1000000)
    ) ERR-INVALID-FUNCTION-PARAMETER)
    (ok (var-set minimum-allowed-bet-amount new-minimum-bet-amount))
  )
)

(define-public (update-maximum-bet-threshold (new-maximum-bet-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-governance-authority)) ERR-UNAUTHORIZED-PLATFORM-ACCESS)
    (asserts! (and 
      (> new-maximum-bet-amount (var-get minimum-allowed-bet-amount))
      (<= new-maximum-bet-amount u1000000000000)
      (>= new-maximum-bet-amount u1000)
    ) ERR-INVALID-FUNCTION-PARAMETER)
    (ok (var-set maximum-allowed-bet-amount new-maximum-bet-amount))
  )
)

;; ADMINISTRATIVE FUNCTIONS

(define-public (transfer-platform-governance (new-governance-authority principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-governance-authority)) ERR-UNAUTHORIZED-PLATFORM-ACCESS)
    (asserts! (not (is-eq new-governance-authority (var-get platform-governance-authority))) ERR-INVALID-FUNCTION-PARAMETER)
    (ok (var-set platform-governance-authority new-governance-authority))
  )
)

(define-public (update-platform-service-name (new-service-name (string-ascii 70)))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-governance-authority)) ERR-UNAUTHORIZED-PLATFORM-ACCESS)
    (asserts! (> (len new-service-name) u0) ERR-INVALID-FUNCTION-PARAMETER)
    (ok (var-set platform-service-name new-service-name))
  )
)

;; READ-ONLY QUERY FUNCTIONS

(define-read-only (get-current-platform-governance-authority)
  (ok (var-get platform-governance-authority))
)

(define-read-only (get-policy-market-information (market-id uint))
  (map-get? policy-prediction-markets { market-identifier: market-id })
)

(define-read-only (get-participant-betting-information (market-id uint) (participant-address principal))
  (map-get? participant-betting-records { market-identifier: market-id, participant-address: participant-address })
)

(define-read-only (get-platform-configuration-settings)
  {
    platform-service-name: (var-get platform-service-name),
    default-market-expiration-period-blocks: (var-get default-market-expiration-period-blocks),
    minimum-allowed-bet-amount: (var-get minimum-allowed-bet-amount),
    maximum-allowed-bet-amount: (var-get maximum-allowed-bet-amount),
    next-available-market-identifier: (var-get next-available-market-identifier)
  }
)