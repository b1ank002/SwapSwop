// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SwapSwopPair} from "../src/SwapSwopPair.sol";
import {ISwapSwopPair} from "../src/interfaces/ISwapSwopPair.sol";
import {LSwapSwopPair} from "../src/libraries/LSwapSwopPair.sol";
import {LpToken} from "../src/SwapSwopLp.sol";
import {MockToken0} from "./testTokens/MockToken0.sol";
import {MockToken1} from "./testTokens/MockToken1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SwapSwopEIP712} from "../src/SwapSwopEIP712.sol";
import {ISwapSwopEIP712} from "../src/interfaces/ISwapSwopEIP712.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SwapSwopPairTest} from "./SwapSwopPairTest.t.sol";

contract SwapSwopEIP712Test is Test {
    SwapSwopPair public swapSwopPair;

    MockToken0 public token0;
    MockToken1 public token1;

    LpToken public lpToken;

    SwapSwopEIP712 public eip712Swap;

    uint256 constant AMOUNT_TOKEN0 = 100_000 * 1e6; // usdt
    uint256 constant AMOUNT_TOKEN1 = 100 * 1e18; // eth

    uint256 public signerSk = 0xA11CE;
    address public signer = vm.addr(signerSk);

    function setUp() public {
        token0 = new MockToken0(address(this), AMOUNT_TOKEN0);
        token1 = new MockToken1(address(this), AMOUNT_TOKEN1);

        eip712Swap = new SwapSwopEIP712();

        swapSwopPair = new SwapSwopPair(address(token0), address(token1), address(eip712Swap));

        lpToken = swapSwopPair.lpToken();
    }

    function test_Initial_State(address _sender) public view {
        assertEq(eip712Swap.getNonce(_sender), 0);
    }

    function test_Verify_Success(address _pair, address _tokenIn, uint256 _amountIn, uint256 _minAmountOut)
        public
        view
        returns (ISwapSwopEIP712.SwapEIP712 memory, bytes memory)
    {
        ISwapSwopEIP712.SwapEIP712 memory p = ISwapSwopEIP712.SwapEIP712({
            pair: _pair,
            sender: signer,
            tokenIn: _tokenIn,
            amountIn: _amountIn,
            minAmountOut: _minAmountOut,
            nonce: eip712Swap.getNonce(signer),
            deadline: block.timestamp + 1 hours
        });

        bytes32 digest = eip712Swap._hashSwap(p);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        console.logBytes(sig);

        assertTrue(eip712Swap.verify(p, sig));

        return (p, sig);
    }

    function test_ExecuteSwap_Success(uint256 _amount0, uint256 _amount1, bool _isToken0, uint256 _amountIn) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        token0.approve(address(swapSwopPair), _amount0);
        token1.approve(address(swapSwopPair), _amount1);
        swapSwopPair.addLiquidity(_amount0, _amount1);

        address tokenIn;
        address tokenOut;
        uint256 reserveIn;
        uint256 reserveOut;

        vm.assume(_amountIn > 0);
        if (_isToken0) {
            vm.assume(_amountIn <= swapSwopPair.reserve0());
            vm.assume(_amountIn <= token0.balanceOf(address(this)));

            tokenIn = address(token0);
            tokenOut = address(token1);
            reserveIn = swapSwopPair.reserve0();
            reserveOut = swapSwopPair.reserve1();
        } else {
            vm.assume(_amountIn <= swapSwopPair.reserve1());
            vm.assume(_amountIn <= token1.balanceOf(address(this)));

            tokenIn = address(token1);
            tokenOut = address(token0);
            reserveIn = swapSwopPair.reserve1();
            reserveOut = swapSwopPair.reserve0();
        }

        IERC20(tokenIn).transfer(signer, _amountIn);
        uint256 amountOut = LSwapSwopPair.getAmountOut(_amountIn, reserveIn, reserveOut);
        vm.assume(amountOut > 0);

        vm.prank(signer);
        IERC20(tokenIn).approve(address(swapSwopPair), _amountIn);

        (ISwapSwopEIP712.SwapEIP712 memory p, bytes memory sig) =
            test_Verify_Success(address(swapSwopPair), tokenIn, _amountIn, 0);

        vm.expectEmit(true, true, true, true);
        emit ISwapSwopEIP712.SwapExecuted(address(swapSwopPair), signer, tokenIn, _amountIn, amountOut);

        eip712Swap.executeSwap(p, sig);

        if (_isToken0) {
            assertEq(swapSwopPair.reserve0(), reserveIn + _amountIn);
            assertEq(swapSwopPair.reserve1(), reserveOut - amountOut);
        } else {
            assertEq(swapSwopPair.reserve0(), reserveOut - amountOut);
            assertEq(swapSwopPair.reserve1(), reserveIn + _amountIn);
        }
    }

    function test_ExecuteSwap_Revert_InvalideSignature(
        uint256 _amountIn,
        address _tokenIn,
        address _pair,
        uint256 _minAmountOut
    ) public {
        (ISwapSwopEIP712.SwapEIP712 memory p, bytes memory sig) =
            test_Verify_Success(address(swapSwopPair), _tokenIn, _amountIn, 0);
        ISwapSwopEIP712.SwapEIP712 memory _p = ISwapSwopEIP712.SwapEIP712({
            pair: _pair,
            sender: signer,
            tokenIn: _tokenIn,
            amountIn: _amountIn,
            minAmountOut: _minAmountOut,
            nonce: eip712Swap.getNonce(signer),
            deadline: block.timestamp + 1 hours
        });

        bytes32 digest = eip712Swap._hashSwap(_p);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        bytes memory _sig = abi.encodePacked(r, s, v);
        vm.assume(keccak256(sig) != keccak256(_sig));

        vm.expectRevert(ISwapSwopEIP712.InvalideSignature.selector);

        eip712Swap.executeSwap(p, _sig);
    }

    function test_ExecuteSwap_Revert_DeadlineExpired(
        uint256 _amountIn,
        address _tokenIn,
        address _pair,
        uint256 _minAmountOut
    ) public {
        ISwapSwopEIP712.SwapEIP712 memory p = ISwapSwopEIP712.SwapEIP712({
            pair: _pair,
            sender: signer,
            tokenIn: _tokenIn,
            amountIn: _amountIn,
            minAmountOut: _minAmountOut,
            nonce: eip712Swap.getNonce(signer),
            deadline: block.timestamp - 1
        });

        bytes32 digest = eip712Swap._hashSwap(p);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert(ISwapSwopEIP712.DeadlineExpired.selector);

        eip712Swap.executeSwap(p, sig);
    }

    function test_ExecuteSwap_Revert_InvalideNonce(
        uint256 _amountIn,
        address _tokenIn,
        address _pair,
        uint256 _minAmountOut,
        uint256 _nonce
    ) public {
        vm.assume(_nonce != eip712Swap.getNonce(signer));

        ISwapSwopEIP712.SwapEIP712 memory p = ISwapSwopEIP712.SwapEIP712({
            pair: _pair,
            sender: signer,
            tokenIn: _tokenIn,
            amountIn: _amountIn,
            minAmountOut: _minAmountOut,
            nonce: _nonce,
            deadline: block.timestamp + 1 hours
        });

        bytes32 digest = eip712Swap._hashSwap(p);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert(ISwapSwopEIP712.InvalideNonce.selector);

        eip712Swap.executeSwap(p, sig);
    }

    function test_ExecuteSwap_Revert_InsufficientOutputAmount(
        uint256 _amount0,
        uint256 _amount1,
        bool _isToken0,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        token0.approve(address(swapSwopPair), _amount0);
        token1.approve(address(swapSwopPair), _amount1);
        swapSwopPair.addLiquidity(_amount0, _amount1);

        address tokenIn;
        address tokenOut;
        uint256 reserveIn;
        uint256 reserveOut;

        vm.assume(_amountIn > 0);
        if (_isToken0) {
            vm.assume(_amountIn <= swapSwopPair.reserve0());
            vm.assume(_amountIn <= token0.balanceOf(address(this)));

            tokenIn = address(token0);
            tokenOut = address(token1);
            reserveIn = swapSwopPair.reserve0();
            reserveOut = swapSwopPair.reserve1();
        } else {
            vm.assume(_amountIn <= swapSwopPair.reserve1());
            vm.assume(_amountIn <= token1.balanceOf(address(this)));

            tokenIn = address(token1);
            tokenOut = address(token0);
            reserveIn = swapSwopPair.reserve1();
            reserveOut = swapSwopPair.reserve0();
        }

        IERC20(tokenIn).transfer(signer, _amountIn);
        uint256 amountOut = LSwapSwopPair.getAmountOut(_amountIn, reserveIn, reserveOut);
        vm.assume(amountOut < _minAmountOut);
        vm.assume(amountOut > 0);

        vm.prank(signer);
        IERC20(tokenIn).approve(address(swapSwopPair), _amountIn);

        (ISwapSwopEIP712.SwapEIP712 memory p, bytes memory sig) =
            test_Verify_Success(address(swapSwopPair), tokenIn, _amountIn, _minAmountOut);

        vm.expectRevert(
            abi.encodeWithSelector(ISwapSwopEIP712.InsufficientOutputAmount.selector, amountOut, _minAmountOut)
        );

        eip712Swap.executeSwap(p, sig);
    }
}
