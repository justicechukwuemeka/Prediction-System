# Policy Oracle: Decentralized Policy Outcome Prediction Market

A comprehensive smart contract platform built on Stacks blockchain that enables users to create prediction markets for policy outcomes, place bets, and claim rewards based on real-world policy decisions.

## Overview

PolicyOracle is a decentralized prediction market platform that allows users to forecast policy outcomes and monetize their predictions. The platform features automatic market expiration, bet refunds for unresolved markets, and comprehensive administrative controls for platform governance.

## Features

- **Market Creation**: Create prediction markets for any policy outcome with customizable betting periods
- **Betting System**: Place bets on binary policy outcomes (yes/no predictions)
- **Automatic Resolution**: Markets can be resolved by creators or platform administrators
- **Reward Distribution**: Winners receive their stake back as rewards
- **Refund System**: Automatic refunds for expired, unresolved markets
- **Administrative Controls**: Platform governance with configurable parameters
- **Data Cleanup**: Remove expired market data to optimize storage

## Contract Architecture

### Core Components

1. **Market Management**: Create, resolve, and manage prediction markets
2. **Betting Engine**: Handle bet placement and validation
3. **Reward System**: Distribute rewards to successful predictors
4. **Administrative Panel**: Platform configuration and governance
5. **Data Storage**: Efficient storage of markets and betting records

### Key Constants

- **Market Timing**:
  - Maximum closing delay: ~1 year (52,560 blocks)
  - Minimum closing delay: ~1 day (144 blocks)
  - Maximum expiration window: ~2 years (105,120 blocks)
  - Minimum description length: 10 characters

- **Betting Limits**:
  - Default minimum bet: 10 STX
  - Default maximum bet: 1,000,000 STX
  - Default expiration period: 10,000 blocks

## Usage Guide

### Creating a Market

```clarity
(create-new-policy-prediction-market "Will Policy X be implemented by 2025?" u1000000)
```

Parameters:
- `description-text`: Market description (10-256 characters)
- `betting-closes-at-block`: Block height when betting closes

### Placing a Bet

```clarity
(place-outcome-prediction-bet u1 true u100)
```

Parameters:
- `market-id`: Unique market identifier
- `predicted-outcome-value`: Your prediction (true/false)
- `bet-amount`: Amount to wager in STX

### Resolving a Market

```clarity
(resolve-policy-market-outcome u1 true)
```

Parameters:
- `market-id`: Market to resolve
- `actual-outcome-result`: The actual outcome (true/false)

*Note: Only market creators or platform administrators can resolve markets*

### Claiming Rewards

```clarity
(claim-prediction-reward u1)
```

Parameters:
- `market-id`: Market where you made a winning prediction

### Claiming Refunds

```clarity
(claim-refund-from-expired-market u1)
```

Parameters:
- `market-id`: Expired market with unresolved outcome

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u1 | ERR-INVALID-MARKET-CLOSING-BLOCK-HEIGHT | Invalid market closing block height |
| u2 | ERR-MARKET-BETTING-PERIOD-ENDED | Betting period has ended |
| u3 | ERR-MARKET-OUTCOME-ALREADY-DETERMINED | Market outcome already resolved |
| u4 | ERR-INVALID-BET-CONFIGURATION | Invalid bet configuration |
| u5 | ERR-MARKET-IDENTIFIER-NOT-FOUND | Market not found |
| u6 | ERR-INSUFFICIENT-ACCOUNT-BALANCE | Insufficient account balance |
| u7 | ERR-MARKET-STILL-ACCEPTING-BETS | Market still accepting bets |
| u8 | ERR-USER-BET-NOT-FOUND | User bet not found |
| u9 | ERR-MARKET-OUTCOME-NOT-RESOLVED | Market outcome not resolved |
| u10 | ERR-PREDICTION-DOES-NOT-MATCH-OUTCOME | Prediction doesn't match outcome |
| u11 | ERR-MARKET-PAST-EXPIRATION-DATE | Market past expiration date |
| u12 | ERR-MARKET-NOT-YET-EXPIRED | Market not yet expired |
| u13 | ERR-UNAUTHORIZED-PLATFORM-ACCESS | Unauthorized platform access |
| u14 | ERR-BET-AMOUNT-BELOW-MINIMUM | Bet amount below minimum |
| u15 | ERR-BET-AMOUNT-EXCEEDS-MAXIMUM | Bet amount exceeds maximum |
| u16 | ERR-INVALID-FUNCTION-PARAMETER | Invalid function parameter |
| u17 | ERR-INVALID-MARKET-IDENTIFIER | Invalid market identifier |

## Administrative Functions

### Platform Configuration

- **Update Market Expiration Period**: Modify default expiration timeframe
- **Update Betting Limits**: Adjust minimum and maximum bet amounts
- **Transfer Governance**: Change platform administrator
- **Update Service Name**: Modify platform branding

### Data Management

- **Remove Expired Markets**: Clean up expired market data
- **View Platform Settings**: Query current configuration

## Read-Only Functions

### Market Information
```clarity
(get-policy-market-information u1)
```

### Betting Information
```clarity
(get-participant-betting-information u1 'SP1234...)
```

### Platform Configuration
```clarity
(get-platform-configuration-settings)
```

### Current Administrator
```clarity
(get-current-platform-governance-authority)
```

## Data Structures

### Market Record
```clarity
{
  market-description-text: (string-ascii 256),
  resolved-outcome-result: (optional bool),
  betting-closes-at-block: uint,
  market-expires-at-block: uint,
  market-creator-address: principal
}
```

### Betting Record
```clarity
{
  wagered-amount: uint,
  predicted-outcome-value: bool
}
```

## Security Features

- **Access Control**: Only authorized users can resolve markets and modify platform settings
- **Validation**: Comprehensive input validation for all parameters
- **Double-Spending Protection**: Bet records are deleted after reward/refund claiming
- **Expiration Management**: Automatic market expiration and cleanup
- **Balance Verification**: Ensures users have sufficient funds before betting

## Deployment Considerations

1. **Initial Setup**: Deploy with appropriate governance authority
2. **Parameter Tuning**: Adjust betting limits and expiration periods based on use case
3. **Security Auditing**: Thoroughly test all functions before mainnet deployment
4. **Monitoring**: Implement monitoring for market creation and resolution activities

## Development Status

This smart contract is production-ready and includes:
- Comprehensive error handling
- Input validation
- Access control mechanisms
- Efficient data structures
- Administrative functions
- Cleanup mechanisms