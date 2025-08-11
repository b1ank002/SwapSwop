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
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Thrown when a signature is invalide
    error InvalideSignature();

    /// @notice Thrown when a deadline of signature is expired
    error DeadlineExpired();

    /// @notice Thrown when a nonce in signature isnt equal nonce of sender
    error InvalideNonce();

    /// @notice Get the domain separator for the EIP712
    /// @return The domain separator
    function getDomainSeparator() external view returns (bytes32);

    /// @notice Get the nonce for the EIP712
    /// @param _sender The sender of the swap
    /// @return The nonce
    function getNonce(address _sender) external view returns (uint256);

    /// @notice Verify the signature of the swap
    /// @param _swapParams The swap parameters
    /// @param _signature The signature of the swap
    /// @return The result of the verification
    function verify(SwapEIP712 memory _swapParams, bytes memory _signature) external view returns (bool);
}
