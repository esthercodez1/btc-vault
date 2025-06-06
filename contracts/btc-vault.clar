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
