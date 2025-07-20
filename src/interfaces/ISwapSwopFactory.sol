// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title SwapSwopFactory
/// @author 0xBlank
/// @notice This contract is used to create and manage SwapSwop pairs
interface ISwapSwopFactory {
    /// @notice Emitted when a new pair is created
    /// @param token0 The first token of the pair
    /// @param token1 The second token of the pair
    /// @param pair The address of the pair
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    /// @notice Thrown when a token is the zero address
    error TokensCannotBeZeroAddress();

    /// @notice Thrown when a tokens are the same
    error TokensCannotBeTheSame();

    /// @notice Thrown when a pair already exists
    error PairAlreadyExists();

    /// @notice Returns the pair address for two tokens
    /// @param tokenA The first token
    /// @param tokenB The second token
    /// @return The pair address
    /// @dev If the pair does not exist or invalid tokens, it will return the zero address
    function getPair(address tokenA, address tokenB) external view returns (address);

    /// @notice Returns all pairs
    /// @return All pairs
    function getAllPairs() external view returns (address[] memory);

    /// @notice Creates a new pair
    /// @param tokenA The first token
    /// @param tokenB The second token
    /// @return The address of the new pair
    function createPair(address tokenA, address tokenB) external returns (address);

}