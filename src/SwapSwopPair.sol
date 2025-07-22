// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/ISwapSwopPair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LSwapSwopPair} from "./libraries/LSwapSwopPair.sol";

contract SwapSwopPair is ISwapSwopPair {
    address public token0;
    address public token1;

    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function addLiquidity(uint256 _amount0, uint256 _amount1) public {
        if (!LSwapSwopPair.isValidLiquidityRatio(reserve0, reserve1, _amount0, _amount1)) {
            revert InvalidLiquidityRatio();
        }

        if (_amount0 == 0) revert InsufficientLiquidityToken0();
        if (_amount1 == 0) revert InsufficientLiquidityToken1();

        require(IERC20(token0).transferFrom(msg.sender, address(this), _amount0), TransferFailed());
        require(IERC20(token1).transferFrom(msg.sender, address(this), _amount1), TransferFailed());

        reserve0 += _amount0;
        reserve1 += _amount1;

        emit AddLiquidity(msg.sender, _amount0, _amount1);
    }

    function removeLiquidity(uint256 _amount0, uint256 _amount1) public {
        if (_amount0 == 0) revert InsufficientLiquidityToken0();
        if (_amount1 == 0) revert InsufficientLiquidityToken1();
        if (_amount0 > reserve0) revert Amount0GreaterThanReserve0();
        if (_amount1 > reserve1) revert Amount1GreaterThanReserve1();

        reserve0 -= _amount0;
        reserve1 -= _amount1;

        require(IERC20(token0).transfer(msg.sender, _amount0), TransferFailed());
        require(IERC20(token1).transfer(msg.sender, _amount1), TransferFailed());

        emit RemoveLiquidity(msg.sender, _amount0, _amount1);
    }

    function swap(address _tokenIn, uint256 _amountIn) public {
        if (_tokenIn == token0 || _tokenIn == token1) revert InvalidTokenAddress();
        if (_tokenIn == address(0)) revert InvalidTokenAddress();
        if (_amountIn == 0) revert InvalidAmount();

        _tokenIn = _tokenIn == token0 ? token0 : token1;
        address tokenOut = _tokenIn == token0 ? token1 : token0;
        uint256 reserveIn = _tokenIn == token0 ? reserve0 : reserve1;
        uint256 reserveOut = _tokenIn == token0 ? reserve0 : reserve1;

        require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), TransferFailed());

        uint256 amountOut = LSwapSwopPair.getAmountOut(_amountIn, reserveIn, reserveOut);

        require(IERC20(tokenOut).transfer(msg.sender, amountOut), TransferFailed());

        reserveIn = IERC20(_tokenIn).balanceOf(address(this));
        reserveOut = IERC20(tokenOut).balanceOf(address(this));

        emit Swap(msg.sender, _tokenIn, _amountIn, tokenOut, amountOut);
    }
}
