;; BTCVault - Decentralized Bitcoin Yield Optimization Protocol
;;
;; Summary:
;; A next-generation DeFi protocol that unlocks Bitcoin's earning potential
;; through secure, non-custodial staking on Stacks Layer 2. BTCVault enables
;; Bitcoin holders to generate sustainable yield while maintaining full control
;; of their assets through innovative tier-based reward mechanics.
;;
;; Description:
;; BTCVault revolutionizes Bitcoin DeFi by providing a comprehensive staking
;; infrastructure that combines security, flexibility, and profitability.
;; The protocol features dynamic reward tiers, automated compounding, loyalty
;; bonuses, and emergency safeguards - all designed to maximize returns while
;; preserving Bitcoin's core principles of decentralization and self-custody.
;;
;; Built for the Stacks ecosystem, BTCVault seamlessly integrates with sBTC
;; to bridge Bitcoin's store-of-value properties with DeFi's yield generation
;; capabilities, creating a new paradigm for productive Bitcoin ownership.

;; PROTOCOL CONSTANTS

(define-constant CONTRACT_VERSION u1)
(define-constant BLOCKS_PER_DAY u144)
(define-constant BLOCKS_PER_YEAR u52560)
(define-constant BASIS_POINTS u10000)
(define-constant MAX_REWARD_RATE u2000) ;; 20% maximum annual yield
(define-constant MIN_STAKE_AMOUNT u1000000) ;; 0.01 sBTC minimum threshold

;; ERROR DEFINITIONS

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ZERO_STAKE (err u101))
(define-constant ERR_NO_STAKE_FOUND (err u102))
(define-constant ERR_TOO_EARLY_TO_UNSTAKE (err u103))
(define-constant ERR_INVALID_REWARD_RATE (err u104))
(define-constant ERR_NOT_ENOUGH_REWARDS (err u105))
(define-constant ERR_CONTRACT_PAUSED (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_INSUFFICIENT_BALANCE (err u108))
(define-constant ERR_TRANSFER_FAILED (err u109))
(define-constant ERR_COOLDOWN_PERIOD (err u110))
(define-constant ERR_TIER_NOT_FOUND (err u111))
(define-constant ERR_INVALID_TIER (err u112))
(define-constant ERR_SLASHING_CONDITIONS_MET (err u113))

;; DATA STRUCTURES

;; Primary staking positions
(define-map stakes
  { staker: principal }
  {
    amount: uint,
    staked-at: uint,
    last-reward-claim: uint,
    tier: uint,
    auto-compound: bool,
  }
)

;; Reward tracking and history
(define-map rewards-claimed
  { staker: principal }
  {
    total-claimed: uint,
    last-claim-block: uint,
    compound-rewards: uint,
  }
)

;; Tier-based reward system configuration
(define-map reward-tiers
  { tier: uint }
  {
    min-amount: uint,
    min-duration: uint,
    reward-multiplier: uint,
    name: (string-ascii 20),
  }
)

;; User engagement and loyalty metrics
(define-map user-stats
  { user: principal }
  {
    total-staked-ever: uint,
    stake-count: uint,
    first-stake-block: uint,
    loyalty-points: uint,
  }
)

;; PROTOCOL STATE VARIABLES

;; Core governance and configuration
(define-data-var contract-owner principal tx-sender)
(define-data-var reward-rate uint u500) ;; 5% base annual rate
(define-data-var reward-pool uint u0)
(define-data-var min-stake-period uint u1440) ;; ~10 days minimum lock
(define-data-var total-staked uint u0)

;; Security and emergency controls
(define-data-var contract-paused bool false)
(define-data-var emergency-withdraw-enabled bool false)
(define-data-var cooldown-period uint u144) ;; 1 day cooldown

;; Economic parameters
(define-data-var total-rewards-distributed uint u0)
(define-data-var protocol-fee-rate uint u100) ;; 1% protocol fee
(define-data-var protocol-fee-pool uint u0)
(define-data-var compound-bonus-rate uint u50) ;; 0.5% auto-compound bonus
(define-data-var max-individual-stake uint u100000000000) ;; 1000 sBTC per user limit

;; TIER SYSTEM INITIALIZATION

;; Bronze Tier - Entry Level
(map-set reward-tiers { tier: u1 } {
  min-amount: u1000000, ;; 0.01 sBTC
  min-duration: u1440, ;; 10 days
  reward-multiplier: u10000, ;; 1x base rate
  name: "Bronze",
}) 
;; Silver Tier - Committed Stakers
(map-set reward-tiers { tier: u2 } {
  min-amount: u10000000, ;; 0.1 sBTC
  min-duration: u4320, ;; 30 days
  reward-multiplier: u12000, ;; 1.2x boost
  name: "Silver",
}) 
;; Gold Tier - Serious Investors
(map-set reward-tiers { tier: u3 } {
  min-amount: u100000000, ;; 1 sBTC
  min-duration: u8640, ;; 60 days
  reward-multiplier: u15000, ;; 1.5x boost
  name: "Gold",
}) 
;; Platinum Tier - Whale Investors
(map-set reward-tiers { tier: u4 } {
  min-amount: u1000000000, ;; 10 sBTC
  min-duration: u17280, ;; 120 days
  reward-multiplier: u20000, ;; 2x boost
  name: "Platinum",
}) 
;; ADMINISTRATIVE FUNCTIONS

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-contract-version)
  CONTRACT_VERSION
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) (ok true))
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (ok (var-set contract-paused true))
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (ok (var-set contract-paused false))
  )
)

(define-public (enable-emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (ok (var-set emergency-withdraw-enabled true))
  )
)

(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-rate MAX_REWARD_RATE) ERR_INVALID_REWARD_RATE)
    (ok (var-set reward-rate new-rate))
  )
)

(define-public (set-min-stake-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_REWARD_RATE)
    (ok (var-set min-stake-period new-period))
  )
)

(define-public (set-protocol-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_REWARD_RATE) ;; Maximum 10%
    (ok (var-set protocol-fee-rate new-rate))
  )
)

(define-public (withdraw-protocol-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= amount (var-get protocol-fee-pool)) ERR_NOT_ENOUGH_REWARDS)
    (var-set protocol-fee-pool (- (var-get protocol-fee-pool) amount))
    (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount (as-contract tx-sender) tx-sender none
    )))
    (ok true)
  )
)

;; LIQUIDITY MANAGEMENT

(define-public (add-to-reward-pool (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

;; UTILITY FUNCTIONS

;; Determine user tier based on stake amount and duration
(define-private (get-user-tier
    (staker principal)
    (amount uint)
    (duration uint)
  )
  (let ((stake-info (map-get? stakes { staker: staker })))
    (if (>= amount u1000000000)
      (if (>= duration u17280)
        u4
        u3
      )
      (if (>= amount u100000000)
        (if (>= duration u8640)
          u3
          u2
        )
        (if (>= amount u10000000)
          (if (>= duration u4320)
            u2
            u1
          )
          u1
        )
      )
    )
  )
)

;; Calculate loyalty bonus based on user engagement
(define-private (calculate-loyalty-bonus (staker principal))
  (match (map-get? user-stats { user: staker })
    stats (let ((loyalty-points (get loyalty-points stats)))
      (if (> loyalty-points u1000)
        u200 ;; 2% bonus for whales
        (if (> loyalty-points u500)
          u100 ;; 1% bonus for veterans
          (if (> loyalty-points u100)
            u50 ;; 0.5% bonus for regulars
            u0
          )
        )
      )
    )
    u0
  )
)

;; Update user statistics and loyalty tracking
(define-private (update-user-stats
    (staker principal)
    (amount uint)
  )
  (match (map-get? user-stats { user: staker })
    prev-stats (map-set user-stats { user: staker } {
      total-staked-ever: (+ (get total-staked-ever prev-stats) amount),
      stake-count: (+ (get stake-count prev-stats) u1),
      first-stake-block: (get first-stake-block prev-stats),
      loyalty-points: (+ (get loyalty-points prev-stats) (/ amount u1000000)),
    })
    (map-set user-stats { user: staker } {
      total-staked-ever: amount,
      stake-count: u1,
      first-stake-block: stacks-block-height,
      loyalty-points: (/ amount u1000000),
    })
  )
)

;; CORE STAKING MECHANICS

(define-public (stake
    (amount uint)
    (auto-compound bool)
  )
  (begin
    ;; Validate contract state and parameters
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (>= amount MIN_STAKE_AMOUNT) ERR_INVALID_AMOUNT)
    ;; Enforce individual stake limits
    (match (map-get? stakes { staker: tx-sender })
      prev-stake (asserts!
        (<= (+ amount (get amount prev-stake)) (var-get max-individual-stake))
        ERR_INVALID_AMOUNT
      )
      (asserts! (<= amount (var-get max-individual-stake)) ERR_INVALID_AMOUNT)
    )
    ;; Transfer sBTC to contract custody
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    ;; Configure stake with appropriate tier
    (let ((user-tier (get-user-tier tx-sender amount u0)))
      (match (map-get? stakes { staker: tx-sender })
        prev-stake
        (begin
          ;; Claim existing rewards before updating stake
          (try! (claim-rewards))
          (map-set stakes { staker: tx-sender } {
            amount: (+ amount (get amount prev-stake)),
            staked-at: stacks-block-height,
            last-reward-claim: stacks-block-height,
            tier: user-tier,
            auto-compound: auto-compound,
          })
        )
        ;; Create new stake position
        (map-set stakes { staker: tx-sender } {
          amount: amount,
          staked-at: stacks-block-height,
          last-reward-claim: stacks-block-height,
          tier: user-tier,
          auto-compound: auto-compound,
        })
      )
    )
    ;; Update protocol metrics
    (var-set total-staked (+ (var-get total-staked) amount))
    (update-user-stats tx-sender amount)
    (ok true)
  )
)

;; REWARD CALCULATION ENGINE

(define-read-only (calculate-rewards (staker principal))
  (match (map-get? stakes { staker: staker })
    stake-info (let (
        (stake-amount (get amount stake-info))
        (stake-duration (- stacks-block-height (get last-reward-claim stake-info)))
        (user-tier (get tier stake-info))
        (tier-info (unwrap! (map-get? reward-tiers { tier: user-tier }) u0))
        (tier-multiplier (get reward-multiplier tier-info))
        (base-reward (/ (* stake-amount (var-get reward-rate)) BASIS_POINTS))
        (time-factor (/ stake-duration BLOCKS_PER_YEAR))
        (tier-bonus (/ (* base-reward tier-multiplier) BASIS_POINTS))
        (loyalty-bonus-rate (calculate-loyalty-bonus staker))
        (loyalty-bonus (/ (* tier-bonus loyalty-bonus-rate) BASIS_POINTS))
        (compound-bonus (if (get auto-compound stake-info)
          (/ (* tier-bonus (var-get compound-bonus-rate)) BASIS_POINTS)
          u0
        ))
        (total-reward (+ tier-bonus loyalty-bonus compound-bonus))
      )
      (/ (* total-reward time-factor) u1)
    )
    u0
  )
)

;; REWARD DISTRIBUTION

(define-public (claim-rewards)
  (let (
      (stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND))
      (reward-amount (calculate-rewards tx-sender))
    )
    ;; Validate claim conditions
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (> reward-amount u0) ERR_NO_STAKE_FOUND)
    (asserts! (<= reward-amount (var-get reward-pool)) ERR_NOT_ENOUGH_REWARDS)
    ;; Process protocol fees
    (let (
        (protocol-fee (/ (* reward-amount (var-get protocol-fee-rate)) BASIS_POINTS))
        (net-reward (- reward-amount protocol-fee))
      )
      ;; Update protocol accounting
      (var-set reward-pool (- (var-get reward-pool) reward-amount))
      (var-set protocol-fee-pool (+ (var-get protocol-fee-pool) protocol-fee))
      (var-set total-rewards-distributed
        (+ (var-get total-rewards-distributed) reward-amount)
      )
      ;; Handle reward distribution based on auto-compound preference
      (if (get auto-compound stake-info)
        (begin
          ;; Compound rewards into stake position
          (map-set stakes { staker: tx-sender } {
            amount: (+ (get amount stake-info) net-reward),
            staked-at: (get staked-at stake-info),
            last-reward-claim: stacks-block-height,
            tier: (get tier stake-info),
            auto-compound: true,
          })
          ;; Update compound tracking
          (match (map-get? rewards-claimed { staker: tx-sender })
            prev-claimed (map-set rewards-claimed { staker: tx-sender } {
              total-claimed: (get total-claimed prev-claimed),
              last-claim-block: stacks-block-height,
              compound-rewards: (+ (get compound-rewards prev-claimed) net-reward),
            })
            (map-set rewards-claimed { staker: tx-sender } {
              total-claimed: u0,
              last-claim-block: stacks-block-height,
              compound-rewards: net-reward,
            })
          )
          (var-set total-staked (+ (var-get total-staked) net-reward))
        )
        (begin
          ;; Direct reward payment to staker
          (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
            transfer net-reward (as-contract tx-sender) tx-sender none
          )))
          ;; Reset reward accumulation
          (map-set stakes { staker: tx-sender } {
            amount: (get amount stake-info),
            staked-at: (get staked-at stake-info),
            last-reward-claim: stacks-block-height,
            tier: (get tier stake-info),
            auto-compound: false,
          })
          ;; Update claim history
          (match (map-get? rewards-claimed { staker: tx-sender })
            prev-claimed (map-set rewards-claimed { staker: tx-sender } {
              total-claimed: (+ (get total-claimed prev-claimed) net-reward),
              last-claim-block: stacks-block-height,
              compound-rewards: (get compound-rewards prev-claimed),
            })
            (map-set rewards-claimed { staker: tx-sender } {
              total-claimed: net-reward,
              last-claim-block: stacks-block-height,
              compound-rewards: u0,
            })
          )
        )
      )
    )
    (ok true)
  )
)

;; UNSTAKING MECHANICS

(define-public (unstake (amount uint))
  (let (
      (stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND))
      (staked-amount (get amount stake-info))
      (staked-at (get staked-at stake-info))
      (stake-duration (- stacks-block-height staked-at))
    )
    ;; Validate unstaking conditions
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    (asserts! (>= staked-amount amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (>= stake-duration (var-get min-stake-period))
      ERR_TOO_EARLY_TO_UNSTAKE
    )
    ;; Enforce cooldown period
    (match (map-get? rewards-claimed { staker: tx-sender })
      claim-info (asserts!
        (>= (- stacks-block-height (get last-claim-block claim-info))
          (var-get cooldown-period)
        )
        ERR_COOLDOWN_PERIOD
      )
      true
    )
    ;; Process pending rewards before unstaking
    (if (> (calculate-rewards tx-sender) u0)
      (try! (claim-rewards))
      true
    )
    ;; Update or remove stake position
    (if (> staked-amount amount)
      (map-set stakes { staker: tx-sender } {
        amount: (- staked-amount amount),
        staked-at: stacks-block-height,
        last-reward-claim: stacks-block-height,
        tier: (get tier stake-info),
        auto-compound: (get auto-compound stake-info),
      })
      (map-delete stakes { staker: tx-sender })
    )
    ;; Update protocol metrics
    (var-set total-staked (- (var-get total-staked) amount))
    ;; Return sBTC to staker
    (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount (as-contract tx-sender) tx-sender none
    )))
    (ok true)
  )
)

;; EMERGENCY PROCEDURES

(define-public (emergency-withdraw)
  (let ((stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND)))
    (asserts! (var-get emergency-withdraw-enabled) ERR_NOT_AUTHORIZED)
    (let ((amount (get amount stake-info)))
      ;; Emergency exit without rewards
      (map-delete stakes { staker: tx-sender })
      (var-set total-staked (- (var-get total-staked) amount))
      (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
        transfer amount (as-contract tx-sender) tx-sender none
      )))
      (ok true)
    )
  )
)

;; USER PREFERENCE MANAGEMENT

(define-public (toggle-auto-compound)
  (let ((stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND)))
    (map-set stakes { staker: tx-sender } {
      amount: (get amount stake-info),
      staked-at: (get staked-at stake-info),
      last-reward-claim: (get last-reward-claim stake-info),
      tier: (get tier stake-info),
      auto-compound: (not (get auto-compound stake-info)),
    })
    (ok (not (get auto-compound stake-info)))
  )
)

;; QUERY INTERFACE

(define-read-only (get-stake-info (staker principal))
  (map-get? stakes { staker: staker })
)

(define-read-only (get-rewards-claimed (staker principal))
  (map-get? rewards-claimed { staker: staker })
)

(define-read-only (get-user-stats (staker principal))
  (map-get? user-stats { user: staker })
)

(define-read-only (get-tier-info (tier uint))
  (map-get? reward-tiers { tier: tier })
)

(define-read-only (get-contract-stats)
  {
    total-staked: (var-get total-staked),
    reward-pool: (var-get reward-pool),
    total-rewards-distributed: (var-get total-rewards-distributed),
    protocol-fee-pool: (var-get protocol-fee-pool),
    reward-rate: (var-get reward-rate),
    is-paused: (var-get contract-paused),
    emergency-enabled: (var-get emergency-withdraw-enabled),
  }
)

(define-read-only (get-reward-rate)
  (var-get reward-rate)
)

(define-read-only (get-min-stake-period)
  (var-get min-stake-period)
)

(define-read-only (get-reward-pool)
  (var-get reward-pool)
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-current-apy)
  (let ((base-rate (var-get reward-rate)))
    (/ (* base-rate u100) u100)
    ;; Convert basis points to percentage
  )
)

;; ANALYTICS & PROJECTIONS

(define-read-only (estimate-rewards
    (staker principal)
    (blocks-ahead uint)
  )
  (match (map-get? stakes { staker: staker })
    stake-info (let (
        (stake-amount (get amount stake-info))
        (projected-duration (+ (- stacks-block-height (get last-reward-claim stake-info))
          blocks-ahead
        ))
        (user-tier (get tier stake-info))
        (tier-info (unwrap! (map-get? reward-tiers { tier: user-tier }) u0))
        (tier-multiplier (get reward-multiplier tier-info))
        (base-reward (/ (* stake-amount (var-get reward-rate)) BASIS_POINTS))
        (time-factor (/ projected-duration BLOCKS_PER_YEAR))
        (tier-bonus (/ (* base-reward tier-multiplier) BASIS_POINTS))
      )
      (/ (* tier-bonus time-factor) u1)
    )
    u0
  )
)

;; PROTOCOL HEALTH MONITORING

(define-read-only (contract-health-check)
  (let (
      (reward-pool-balance (var-get reward-pool))
      (total-staked-amount (var-get total-staked))
      (reward-ratio (if (> total-staked-amount u0)
        (/ (* reward-pool-balance u100) total-staked-amount)
        u0
      ))
    )
    {
      reward-pool-ratio: reward-ratio,
      is-healthy: (> reward-ratio u10), ;; Healthy: 10%+ reserve ratio
      contract-version: CONTRACT_VERSION,
      protocol-status: "operational",
    }
  )
)
