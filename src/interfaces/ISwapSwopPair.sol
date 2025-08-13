// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ISwapSwopPair
/// @author 0xBlank
/// @notice This contract is used to add, remove  and swap liquidity in a pair
interface ISwapSwopPair {
    /// @notice Thrown when the amount of token0 is insufficient
    error InsufficientLiquidityToken0();

    /// @notice Thrown when the amount of token1 is insufficient
    error InsufficientLiquidityToken1();

    /// @notice Thrown when a transfer fails
    error TransferFailed();

    /// @notice Thrown when the token address is zero address
    error InvalidTokenAddress();

    /// @notice Thrown when the amount is zero
    error InvalidAmount();

    /// @notice Thrown when the liquidity ratio is invalid
    error InvalidLiquidityRatio();

    /// @notice Thrown when the amount of lp token is insufficient
    error InsufficientLiquidityLpToken();

    /// @notice Thrown when the liquidity is insufficient
    error InsufficientLiquidity();

    /// @notice Thrown when the balance is insufficient
    error InsufficientBalance();

    /// @notice Emitted when liquidity is added
    /// @param user The user who added liquidity
    /// @param amount0 The amount of token0 added
    /// @param amount1 The amount of token1 added
    /// @param amountLpToken The amount of lp token added
    event AddLiquidity(address indexed user, uint256 amount0, uint256 amount1, uint256 amountLpToken);

    /// @notice Emitted when liquidity is removed
    /// @param user The user who removed liquidity
    /// @param amount0 The amount of token0 removed
    /// @param amount1 The amount of token1 removed
    /// @param amountLpToken The amount of lp token removed
    event RemoveLiquidity(address indexed user, uint256 amount0, uint256 amount1, uint256 amountLpToken);

    /// @notice Emitted when liquidity is swapped
    /// @param user The user who swapped liquidity
    /// @param tokenIn The token that was swapped in
    /// @param amountIn The amount of token that was swapped in
    /// @param tokenOut The token that was swapped out
    /// @param amountOut The amount of token that was swapped out
    event Swap(
        address indexed user, address indexed tokenIn, uint256 amountIn, address indexed tokenOut, uint256 amountOut
    );

    /// @notice Adds liquidity to the pair
    /// @param _amount0 The amount of token0 to add
    /// @param _amount1 The amount of token1 to add
    /// @dev add allowance to the token0 and token1
    function addLiquidity(uint256 _amount0, uint256 _amount1) external;

    /// @notice Removes liquidity from the pair
    /// @param _amountLpToken The amount of lp token to remove
    /// @dev add allowance to the lp token
    function removeLiquidity(uint256 _amountLpToken) external;

    /// @notice Swaps liquidity in the pair
    /// @param _sender The sender of the swap
    /// @param _tokenIn The token to swap in
    /// @param _amountIn The amount of token to swap in
    /// @return The amount out
    /// @dev add allowance to the tokenIn
    function swap(address _sender, address _tokenIn, uint256 _amountIn) external returns (uint256);
}
