# Portfolio Margin System

## Overview

Portfolio Margin System is a decentralized margin trading protocol that unifies Morpho Blue lending markets with RISEx perpetual futures trading. The system enables traders to deposit collateral, borrow USDC, and trade perpetuals while maintaining unified risk management across both protocols.

### Key Innovation

Sub-accounts keep all funds internal without transferring to user wallets. This vault-like approach enables atomic operations and unified portfolio health calculations across lending and trading positions.

## Architecture

### Core Components

**PortfolioMarginManager**
- Central authority for the system
- Deploys and manages sub-accounts
- Calculates unified health across protocols
- Executes liquidations
- Manages market configurations

**PortfolioSubAccount**
- Deployed as minimal proxy for gas efficiency
- Holds all user positions (collateral, loans, trades)
- Integrates with Morpho Blue and RISEx
- Executes user operations through manager approval

### Fund Flow
```
User → Sub-Account → Morpho (deposit collateral)
                  → Morpho (borrow USDC)
                  → RISEx (deposit USDC)
                  → RISEx (trade perpetuals)
```

## Features

### Implemented
- Sub-account deployment via minimal proxy pattern
- Morpho Blue integration (supply, borrow, withdraw, repay)
- RISEx deposit functionality
- Order placement infrastructure (blocked by testnet restrictions)
- Unified health calculations
- Basic liquidation framework

### Work in Progress
- Complete liquidation logic with priority system
- Extended market support beyond WETH
- Frontend interface
- Advanced risk parameters

## Technical Notes

### RISEx Integration
- Deposits via sub-accounts work correctly
- Order placement currently blocked by testnet error 0xf44ad03f
- Whitelist checks pass on testnet
- RISEx uses 18 decimal precision internally

## Getting Started

### Prerequisites
- Foundry
- RISE testnet RPC access

### Installation

```bash
git clone <repository>
cd margin-risex
forge install
forge build
```

### Testing

```bash
# Run tests with RISE testnet fork
forge test --fork-url https://testnet.riselabs.xyz -vv
```

## Usage Example

```solidity
// Create sub-account
address subAccount = manager.createSubAccount(user);

// Deposit collateral
WETH.approve(subAccount, 10e18);
PortfolioSubAccount(subAccount).depositCollateral(marketParams, 10e18);

// Borrow USDC
PortfolioSubAccount(subAccount).borrowUSDC(marketParams, 20_000e6);

// Deposit to RISEx
PortfolioSubAccount(subAccount).depositToRISEx(20_000e6);

// Place order (currently blocked on testnet)
bytes memory orderData = encoder.encodePlaceOrder(params);
PortfolioSubAccount(subAccount).placeOrder(orderData);
```

## Development Status

### Complete
- PortfolioMarginManager contract
- PortfolioSubAccount with minimal proxy deployment
- Morpho Blue integration (supply, borrow, withdraw, repay)
- RISEx deposit functionality
- Order placement infrastructure
- Unified health calculations
- Basic test coverage

### Known Issues
- RISEx order placement blocked by testnet restrictions (error 0xf44ad03f)
- Testnet-specific behavior documented in issue.md

## Contract Addresses (RISE Testnet)

See deployments/ folder for current addresses

## License

MIT