// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library LSwapSwopPair {
    // x * y = k
    // (x + amountIn) * (y - amountOut) = k
    // amountOut = (amountIn * y) / (x + amountIn))

    /// @notice Get the amount of tokenOut for the given amount of tokenIn
    /// @param amountIn The amount of tokenIn
    /// @param reserveIn The reserve of tokenIn
    /// @param reserveOut The reserve of tokenOut
    /// @return The amount of tokenOut
    /// @dev 997 is the fee for the swap (1000 - 3)
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    /// @notice Check if the liquidity ratio is valid
    /// @param reserve0 The reserve of token0
    /// @param reserve1 The reserve of token1
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    /// @return True if the liquidity ratio is valid, false otherwise
    /// @dev 97 is the lower bound for the liquidity ratio (100 - 3)
    /// @dev 103 is the upper bound for the liquidity ratio (100 + 3)
    function isValidLiquidityRatio(uint256 reserve0, uint256 reserve1, uint256 amount0, uint256 amount1)
        internal
        pure
        returns (bool)
    {
        if (reserve0 == 0 || reserve1 == 0) return true;

        uint256 ratioPool = reserve0 * 1e18 / reserve1;
        uint256 ratioUser = amount0 * 1e18 / amount1;

        uint256 lowerBound = ratioPool * 97 / 100;
        uint256 upperBound = ratioPool * 103 / 100;

        return ratioUser >= lowerBound && ratioUser <= upperBound;
    }
}
