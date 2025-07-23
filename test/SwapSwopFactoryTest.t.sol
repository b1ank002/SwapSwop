// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {ISwapSwopFactory} from "../src/interfaces/ISwapSwopFactory.sol";
import {SwapSwopFactory} from "../src/SwapSwopFactory.sol";
import {MockToken0} from "./testTokens/MockToken0.sol";
import {MockToken1} from "./testTokens/MockToken1.sol";

contract SwapSwopFactoryTest is Test {
    SwapSwopFactory public swapSwopFactory;

    MockToken0 public token0;
    MockToken1 public token1;

    uint256 constant AMOUNT_TOKEN0 = 100_000 * 1e6; // usdt
    uint256 constant AMOUNT_TOKEN1 = 100 * 1e18; // eth

    function setUp() public {
        swapSwopFactory = new SwapSwopFactory();
        token0 = new MockToken0(address(this), AMOUNT_TOKEN0);
        token1 = new MockToken1(address(this), AMOUNT_TOKEN1);
    }

    function test_Initial_State(address _token0, address _token1) public view {
        assertEq(swapSwopFactory.getPair(_token0, _token1), address(0));
        assertEq(swapSwopFactory.getPair(_token1, _token0), address(0));
        assertEq(swapSwopFactory.getAllPairs().length, 0);

        assertEq(token0.balanceOf(address(this)), AMOUNT_TOKEN0);
        assertEq(token1.balanceOf(address(this)), AMOUNT_TOKEN1);
    }

    function test_Create_Pair_Success(address _token0, address _token1) public returns (address) {
        vm.assume(_token0 != address(0) && _token1 != address(0));
        vm.assume(_token0 != _token1);

        vm.expectEmit(true, true, false, false);
        if (_token0 < _token1) {
            emit ISwapSwopFactory.PairCreated(_token0, _token1, address(0), 1);
        } else {
            emit ISwapSwopFactory.PairCreated(_token1, _token0, address(0), 1);
        }
        address pair = swapSwopFactory.createPair(_token0, _token1);

        console.log("address pair: ", pair);

        assertEq(pair, swapSwopFactory.getPair(_token0, _token1));
        assertEq(pair, swapSwopFactory.getPair(_token1, _token0));
        assertEq(swapSwopFactory.getAllPairs().length, 1);
        assertEq(swapSwopFactory.getAllPairs()[0], pair);

        return pair;
    }

    function test_Create_Pair_Revert_TokensCannotBeZeroAddress(address _token0, address _token1) public {
        vm.expectRevert(ISwapSwopFactory.TokensCannotBeZeroAddress.selector);
        swapSwopFactory.createPair(address(0), _token1);

        vm.expectRevert(ISwapSwopFactory.TokensCannotBeZeroAddress.selector);
        swapSwopFactory.createPair(_token0, address(0));

        vm.expectRevert(ISwapSwopFactory.TokensCannotBeZeroAddress.selector);
        swapSwopFactory.createPair(address(0), address(0));

        assertEq(address(0), swapSwopFactory.getPair(_token0, _token1));
        assertEq(address(0), swapSwopFactory.getPair(_token1, _token0));
        assertEq(swapSwopFactory.getAllPairs().length, 0);
    }

    function test_Create_Pair_Revert_TokensCannotBeTheSame(address _token) public {
        vm.assume(_token != address(0));

        vm.expectRevert(ISwapSwopFactory.TokensCannotBeTheSame.selector);
        swapSwopFactory.createPair(_token, _token);

        assertEq(address(0), swapSwopFactory.getPair(_token, _token));
        assertEq(swapSwopFactory.getAllPairs().length, 0);
    }

    function test_Create_Pair_Revert_PairAlreadyExists(address _token0, address _token1) public {
        vm.assume(_token0 != address(0) && _token1 != address(0));
        vm.assume(_token0 != _token1);

        address pair = test_Create_Pair_Success(_token0, _token1);

        vm.expectRevert(ISwapSwopFactory.PairAlreadyExists.selector);
        swapSwopFactory.createPair(_token0, _token1);

        vm.expectRevert(ISwapSwopFactory.PairAlreadyExists.selector);
        swapSwopFactory.createPair(_token1, _token0);

        assertEq(pair, swapSwopFactory.getPair(_token0, _token1));
        assertEq(pair, swapSwopFactory.getPair(_token1, _token0));
        assertEq(swapSwopFactory.getAllPairs().length, 1);
        assertEq(swapSwopFactory.getAllPairs()[0], pair);
    }
}
