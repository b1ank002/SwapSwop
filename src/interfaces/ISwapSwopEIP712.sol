// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISwapSwopEIP712 {
    /// @notice The struct of parameters for the swap using EIP712
    /// @param pair The pair of the swap
    /// @param sender The sender of the swap
    /// @param tokenIn The token that is being swapped in
    /// @param amountIn The amount of token that is being swapped in
    /// @param nonce The nonce of the swap
    /// @param deadline The deadline of the swap
    struct SwapEIP712 {
        address pair;
        address sender;
        address tokenIn;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Thrown when a signature is invalide
    error InvalideSignature();

    /// @notice Thrown when a deadline of signature is expired
    error DeadlineExpired();

    /// @notice Thrown when a nonce in signature isnt equal nonce of sender
    error InvalideNonce();

    /// @notice Thrown when actual output amount less then min output amount
    /// @param actual The actual amount out
    /// @param minAmountOut The min amount out
    error InsufficientOutputAmount(uint256 actual, uint256 minAmountOut);

    /// @notice Swaps liquidity in the pair using EIP712
    /// @param pair The address of the pair of tokens
    /// @param sender The sender of the swap
    /// @param tokenIn The token to swap in
    /// @param amountIn The amount of token to swap in
    /// @param amountOut The amount of token that was swapped out
    event SwapExecuted(
        address indexed pair, address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut
    );

    /// @notice Get the nonce for the EIP712
    /// @param _sender The sender of the swap
    /// @return The nonce
    function getNonce(address _sender) external view returns (uint256);

    /// @notice Verify the signature of the swap
    /// @param _swapParams The swap parameters
    /// @param _signature The signature of the swap
    /// @return The result of the verification
    function verify(SwapEIP712 memory _swapParams, bytes memory _signature) external view returns (bool);

    /// @notice Execute a swap function on pair contract
    /// @param _swapParams The struct with params for swap
    /// @param _signature The signature for swap
    /// @return True if swap is executed
    /// @dev Make approve for tokenIn for amountIn
    function executeSwap(SwapEIP712 memory _swapParams, bytes memory _signature) external returns (bool);
}
