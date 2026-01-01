# Portfolio Margin System

> DEVELOPMENT IN PROGRESS - Not ready for production use

## Overview

**Portfolio Margin System** is a decentralized margin trading protocol that unifies Morpho Blue's lending markets with RISEx's perpetual futures trading. The system enables traders to:

- Deposit collateral (WETH, WBTC) to Morpho Blue
- Borrow USDC against collateral
- Use borrowed USDC to trade perpetuals on RISEx
- Maintain unified risk management across both protocols

### Key Innovation

Unlike traditional systems where borrowed funds go to the user's wallet, our sub-accounts keep all funds internal, similar to how Yearn vaults operate. This enables atomic operations and better risk management.

## Architecture

### Core Components

#### 1. **PortfolioMarginManager**
- Central authority for the system
- Deploys sub-accounts for users
- Calculates unified health across Morpho and RISEx
- Executes liquidations when necessary
- Manages market configurations

#### 2. **PortfolioSubAccount**
- Deployed as minimal proxy (EIP-1167) for each user
- **Holds all user funds** - collateral, borrowed USDC, and trading positions
- Funds never leave the sub-account unless explicitly withdrawn
- Integrates with both Morpho Blue and RISEx

#### 3. **Fund Flow**
```
User → Sub-Account → Morpho (deposit collateral)
                  ↓
                  → Morpho (borrow USDC to sub-account)
                  ↓
                  → RISEx Deposit Contract (deposit USDC)
                  ↓
                  → RISEx (trade perpetuals)
```

## Key Features

### Sub-Account Design
- Each user gets a dedicated smart contract wallet
- All operations happen within the sub-account
- Borrowed funds stay in sub-account (never sent to user)
- Enables atomic operations and better composability

### Unified Portfolio Margin
- Cross-margining between Morpho loans and RISEx positions
- RISEx profits can prevent Morpho liquidations
- Single health factor across both protocols
- Efficient capital utilization

### Supported Operations
1. **Deposit Collateral**: User deposits WETH/WBTC to sub-account → Morpho
2. **Borrow USDC**: Sub-account borrows from Morpho (keeps funds)
3. **Deposit to RISEx**: Sub-account deposits USDC to RISEx via Deposit contract
4. **Trade Perpetuals**: Sub-account places orders on RISEx
5. **Withdraw**: User can withdraw available funds

## Technical Implementation

### RISEx Integration
- Direct deposits to PerpsManager (skip Deposit contract which mints)
- No decimal conversion needed (use USDC's native 6 decimals)
- Order encoding via RISExOrderEncoder
- Whitelist always returns true on testnet
- **Important**: Deposits from contracts revert with `NotActivated` but actually succeed (check logs/equity)

## Getting Started

### Prerequisites
- [Foundry](https://github.com/foundry-rs/foundry)
- RISE testnet RPC access
- Node.js for running deployment scripts

### Installation

```bash
# Clone repository
git clone https://github.com/your-repo/portfolio-margin
cd portfolio-margin

# Install dependencies
forge install

# Build
forge build
```

### Testing

```bash
# Run tests with RISE testnet fork
FORK_RISE_TESTNET=true forge test --fork-url https://indexing.testnet.riselabs.xyz -vv
```

## Usage Example

```solidity
// 1. User creates sub-account
address subAccount = manager.createSubAccount(user);

// 2. User deposits WETH collateral
WETH.approve(subAccount, 10e18);
PortfolioSubAccount(subAccount).depositCollateral(marketParams, 10e18);

// 3. Sub-account borrows USDC (stays in sub-account)
PortfolioSubAccount(subAccount).borrowUSDC(marketParams, 20_000e6, false);

// 4. Sub-account deposits USDC to RISEx
PortfolioSubAccount(subAccount).depositToRisEx(20_000e6);

// 5. Sub-account trades on RISEx
bytes memory orderData = orderEncoder.encodePlaceOrder(params);
PortfolioSubAccount(subAccount).placeOrder(orderData);

// 6. Monitor unified health
HealthStatus memory health = manager.getPortfolioHealth(user);
```

## Current Development Status

### Implemented ✅
- BasicSubAccount that can hold funds and interact with RISEx
- Direct RISEx deposits via PerpsManager (bypassing Deposit contract)
- RISEx equity tracking and position management
- USDC proxy issues resolved with Shanghai EVM
- RISExOrderEncoder for order formatting
- Basic test infrastructure

### In Progress 🚧
- Morpho Blue integration in sub-accounts
- Unified health calculations across protocols
- Order placement and position management
- Liquidation mechanisms
- Refactoring PortfolioSubAccount to work without proxy pattern

### Next Steps 📋
- Create MorphoAdapter for lending integration
- Implement full user flow (deposit → borrow → trade)
- Add liquidation logic
- Deploy complete system to RISE testnet
- Frontend interface

See [PLAN.md](./PLAN.md) for detailed development plan.

## Contract Addresses (RISE Testnet)

- **Morpho Blue**: `0x70374FB7a93fD277E66C525B93f810A7D61d5606`
- **USDC**: `0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58`
- **RISEx PerpsManager**: `0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4`
- **RISEx Deposit**: `0x5BC20A936EfEE0d758A3c168d2f017c83805B986`

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Disclaimer

**UNAUDITED SOFTWARE** - Do not use in production. This is experimental software under active development.