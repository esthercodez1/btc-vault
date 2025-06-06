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

;; PROTOCOL STATE VARIABLES

;; Core governance and configuration
(define-data-var contract-owner principal tx-sender)
(define-data-var min-stake-period uint u1440) ;; ~10 days minimum lock
(define-data-var total-staked uint u0)

;; Security and emergency controls
(define-data-var contract-paused bool false)
(define-data-var emergency-withdraw-enabled bool false)
(define-data-var cooldown-period uint u144) ;; 1 day cooldown

;; Economic parameters
(define-data-var max-individual-stake uint u100000000000) ;; 1000 sBTC per user limit

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

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-min-stake-period)
  (var-get min-stake-period)
)

;; ADMINISTRATIVE FUNCTIONS

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)