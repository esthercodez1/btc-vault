# BTCVault - Decentralized Bitcoin Yield Optimization Protocol

## Overview

BTCVault is a next-generation DeFi protocol that unlocks Bitcoin's earning potential through secure, non-custodial staking on Stacks Layer 2. The protocol enables Bitcoin holders to generate sustainable yield while maintaining full control of their assets through innovative tier-based reward mechanics.

Built for the Stacks ecosystem, BTCVault seamlessly integrates with sBTC to bridge Bitcoin's store-of-value properties with DeFi's yield generation capabilities, creating a new paradigm for productive Bitcoin ownership.

## Key Features

### 🏆 Tier-Based Reward System

- **Bronze Tier**: Entry level (0.01+ sBTC, 10+ days) - 1x base rate
- **Silver Tier**: Committed stakers (0.1+ sBTC, 30+ days) - 1.2x multiplier
- **Gold Tier**: Serious investors (1+ sBTC, 60+ days) - 1.5x multiplier  
- **Platinum Tier**: Whale investors (10+ sBTC, 120+ days) - 2x multiplier

### 💎 Advanced Features

- **Auto-Compounding**: Automatic reward reinvestment with 0.5% bonus
- **Loyalty Rewards**: Additional bonuses based on user engagement history
- **Flexible Staking**: Partial unstaking and stake management
- **Emergency Safeguards**: Emergency withdrawal capabilities
- **Protocol Governance**: Administrative controls and parameter adjustment

### 🔒 Security & Compliance

- Non-custodial architecture with self-custody preservation
- Minimum stake periods to prevent gaming
- Cooldown periods for reward claims
- Individual stake limits and protocol fee management
- Emergency pause functionality

## Protocol Specifications

### Core Parameters

- **Minimum Stake**: 0.01 sBTC (1,000,000 satoshis)
- **Maximum Individual Stake**: 1,000 sBTC per user
- **Base Annual Yield**: 5% (configurable up to 20%)
- **Minimum Lock Period**: ~10 days (1,440 blocks)
- **Protocol Fee**: 1% of rewards
- **Cooldown Period**: 1 day between reward claims

### Reward Calculation

Rewards are calculated using the following formula:

```
Total Reward = (Base Reward × Tier Multiplier + Loyalty Bonus + Compound Bonus) × Time Factor
```

Where:

- **Base Reward** = (Stake Amount × Reward Rate) / 10,000
- **Tier Multiplier** = Multiplier based on user tier (1x to 2x)
- **Loyalty Bonus** = 0% to 2% based on engagement history
- **Compound Bonus** = 0.5% additional for auto-compound users
- **Time Factor** = Stake Duration / Blocks Per Year

## Getting Started

### Prerequisites

- Stacks wallet with sBTC balance
- Understanding of DeFi staking mechanics
- Familiarity with Stacks blockchain

### Basic Usage Flow

1. **Stake sBTC**

   ```clarity
   (contract-call? .btcvault stake amount auto-compound-enabled)
   ```

2. **Monitor Rewards**

   ```clarity
   (contract-call? .btcvault calculate-rewards staker-address)
   ```

3. **Claim Rewards**

   ```clarity
   (contract-call? .btcvault claim-rewards)
   ```

4. **Unstake**

   ```clarity
   (contract-call? .btcvault unstake amount)
   ```

### Query Functions

#### Get Stake Information

```clarity
(contract-call? .btcvault get-stake-info staker-address)
```

#### Check Contract Statistics

```clarity
(contract-call? .btcvault get-contract-stats)
```

#### Estimate Future Rewards

```clarity
(contract-call? .btcvault estimate-rewards staker-address blocks-ahead)
```

## Architecture

### Core Components

#### Data Structures

- **Stakes Map**: Primary staking positions with tier and compound preferences
- **Rewards Claimed Map**: Reward history and compound tracking
- **Reward Tiers Map**: Tier configuration and multipliers
- **User Stats Map**: Engagement metrics and loyalty tracking

#### State Variables

- **Governance**: Contract owner, pause state, emergency controls
- **Economic**: Reward rates, fee structures, pool balances
- **Security**: Cooldown periods, stake limits, withdrawal controls

#### Function Categories

- **Administrative**: Owner-only governance and parameter management
- **Core Staking**: Stake, unstake, and reward mechanics
- **User Management**: Preference settings and account management
- **Query Interface**: Read-only functions for data access
- **Analytics**: Reward estimation and protocol health monitoring

### Security Model

#### Multi-Layer Protection

1. **Access Control**: Owner-only administrative functions
2. **Economic Safeguards**: Minimum stakes, cooldown periods, fee caps
3. **Emergency Controls**: Contract pause and emergency withdrawal
4. **Validation Logic**: Comprehensive input validation and error handling

#### Risk Mitigation

- Individual stake limits prevent centralization
- Protocol fee caps protect against governance attacks
- Emergency withdrawal preserves user funds during crises
- Cooldown periods prevent reward gaming

## Integration Guide

### For Developers

#### Contract Integration

```clarity
;; Stake sBTC with auto-compound
(contract-call? 'SP000000000000000000002Q6VF78.btcvault 
  stake u10000000 true) ;; 0.1 sBTC with auto-compound

;; Check current rewards
(contract-call? 'SP000000000000000000002Q6VF78.btcvault 
  calculate-rewards 'SP1234567890ABCDEF)
```

#### Frontend Integration

The protocol provides comprehensive read-only functions for building user interfaces:

- Real-time reward calculations
- Tier status and progression tracking
- Historical performance analytics
- Protocol health monitoring

### For Liquidity Providers

#### Add Rewards to Pool

```clarity
(contract-call? .btcvault add-to-reward-pool amount)
```

Protocol fees and external contributions maintain the reward pool sustainability.

## Governance

### Administrative Functions

- **Reward Rate Adjustment**: Modify base APY (0-20% cap)
- **Fee Management**: Adjust protocol fees (0-10% cap)
- **Security Controls**: Pause/unpause, emergency settings
- **Parameter Tuning**: Stake periods, cooldowns, limits

### Decentralization Roadmap

- Initial centralized governance for protocol stability
- Progressive decentralization through community governance
- Multi-signature controls and timelock mechanisms
- Community proposal and voting systems

## Risk Disclosure

### Protocol Risks

- **Smart Contract Risk**: Potential bugs or vulnerabilities
- **Economic Risk**: Reward pool depletion or token volatility
- **Governance Risk**: Centralized control during early phases
- **Technical Risk**: Stacks network dependencies

### User Considerations

- **Lock-up Periods**: Minimum staking duration requirements
- **Impermanent Loss**: Not applicable (single-asset staking)
- **Slashing Risk**: None (no validator obligations)
- **Fee Impact**: 1% protocol fee on rewards

## Development

### Contract Version

Current version: v1.0
