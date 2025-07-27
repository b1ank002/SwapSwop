// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/ISwapSwopFactory.sol";
import "./SwapSwopPair.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract SwapSwopFactory is ERC165, ISwapSwopFactory {
    mapping(address => mapping(address => address)) public pairs;

    address[] public allPairs;

    function getPair(address tokenA, address tokenB) public view returns (address) {
        return pairs[tokenA][tokenB];
    }

    function getAllPairs() public view returns (address[] memory) {
        return allPairs;
    }

    function createPair(address tokenA, address tokenB) public returns (address) {
        if (tokenA == address(0) || tokenB == address(0)) revert TokensCannotBeZeroAddress();
        if (tokenA == tokenB) revert TokensCannotBeTheSame();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (pairs[token0][token1] != address(0)) revert PairAlreadyExists();

        address pair = address(new SwapSwopPair(token0, token1));
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);

        return pair;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISwapSwopFactory).interfaceId || super.supportsInterface(interfaceId);
    }
}
