# SwapSwop DEX

**SwapSwop** is a lightweight decentralized exchange protocol designed for token swaps and liquidity management. It allows users to create token pairs, provide/remove liquidity, and perform on-chain swaps securely and efficiently.

> ✅ Built with **Solidity ^0.8.30**  
> ✅ LP token using **OpenZeppelin ERC-20**  
> ✅ Tested and structured for real deployment (via **Foundry**)

---

## ✨ Features

- 🏗️ **Factory Contract** – deploy and manage SwapSwop token pairs
- 💧 **Pair Contract** – add/remove liquidity, execute token swaps
- 🎟️ **ERC-20 LP Token** – mintable & burnable, fully compliant
- 🚨 **Custom Errors** – low-gas error handling
- 🧾 **Events** – full transparency on all key actions

---

## 📦 Contracts Overview

### 🏭 `ISwapSwopFactory`

Handles pair creation and lookup:

| Function | Description |
|----------|-------------|
| `createPair(tokenA, tokenB)` | Deploys a new pair contract |
| `getPair(tokenA, tokenB)` | Returns the address of an existing pair |
| `getAllPairs()` | Returns all pair addresses |

**Events:**
- `PairCreated(token0, token1, pair, id)`

**Errors:**
- `TokensCannotBeZeroAddress`
- `TokensCannotBeTheSame`
- `PairAlreadyExists`

---

### 🔁 `ISwapSwopPair`

Manages liquidity and swaps within a single pair:

| Function | Description |
|----------|-------------|
| `addLiquidity(amount0, amount1)` | Add tokens and receive LP tokens |
| `removeLiquidity(amountLpToken)` | Burn LP tokens and withdraw reserves |
| `swap(tokenIn, amountIn)` | Swap one token for the other |

**Events:**
- `AddLiquidity(user, amount0, amount1, amountLpToken)`
- `RemoveLiquidity(user, amount0, amount1, amountLpToken)`
- `Swap(user, tokenIn, tokenOut, amountIn, amountOut)`

**Errors include:**
- `InsufficientLiquidityToken`, `InvalidAmount`, `TransferFailed`, `InsufficientBalance`, etc.

---

### 🪙 `LpToken`

A standard LP token with owner-controlled minting:

- Based on OpenZeppelin `ERC20`, `ERC20Burnable`, and `Ownable`
- Symbol: `LTP`
- Only the pair(owner) contract can mint LP tokens

```solidity
function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
}
