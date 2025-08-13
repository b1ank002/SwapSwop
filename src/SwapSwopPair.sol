// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/ISwapSwopPair.sol";
import "./SwapSwopLp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LSwapSwopPair} from "./libraries/LSwapSwopPair.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {SwapSwopEIP712} from "./SwapSwopEIP712.sol";

contract SwapSwopPair is ERC165, ISwapSwopPair, SwapSwopEIP712 {
    address public token0;
    address public token1;

    LpToken public lpToken;

    SwapSwopEIP712 public eip712Swap;

    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address _token0, address _token1, address _eip712Swap) {
        token0 = _token0;
        token1 = _token1;

        lpToken = new LpToken(address(this));

        eip712Swap = SwapSwopEIP712(_eip712Swap);
    }

    function addLiquidity(uint256 _amount0, uint256 _amount1) public {
        if (_amount0 == 0) revert InsufficientLiquidityToken0();
        if (_amount1 == 0) revert InsufficientLiquidityToken1();

        if (!LSwapSwopPair.isValidLiquidityRatio(reserve0, reserve1, _amount0, _amount1)) {
            revert InvalidLiquidityRatio();
        }

        require(IERC20(token0).transferFrom(msg.sender, address(this), _amount0), TransferFailed());
        require(IERC20(token1).transferFrom(msg.sender, address(this), _amount1), TransferFailed());

        reserve0 += _amount0;
        reserve1 += _amount1;

        uint256 amountLpToken =
            LSwapSwopPair.getAmountLpToken(_amount0, _amount1, reserve0, reserve1, lpToken.totalSupply());
        lpToken.mint(msg.sender, amountLpToken);

        emit AddLiquidity(msg.sender, _amount0, _amount1, amountLpToken);
    }

    function removeLiquidity(uint256 _amountLpToken) public {
        if (_amountLpToken > lpToken.balanceOf(msg.sender)) revert InsufficientLiquidityLpToken();

        (uint256 amount0, uint256 amount1) =
            LSwapSwopPair.getAmountToken0andToken1(_amountLpToken, reserve0, reserve1, lpToken.totalSupply());

        reserve0 -= amount0;
        reserve1 -= amount1;

        lpToken.burnFrom(msg.sender, _amountLpToken);

        require(IERC20(token0).transfer(msg.sender, amount0), TransferFailed());
        require(IERC20(token1).transfer(msg.sender, amount1), TransferFailed());

        emit RemoveLiquidity(msg.sender, amount0, amount1, _amountLpToken);
    }

    function swap(address _sender, address _tokenIn, uint256 _amountIn) public returns (uint256) {
        if (_tokenIn != token0 && _tokenIn != token1) revert InvalidTokenAddress();
        if (_amountIn == 0) revert InvalidAmount();
        if (reserve0 == 0 || reserve1 == 0) revert InsufficientLiquidity();

        address _msgSender = msg.sender == address(eip712Swap) ? _sender : msg.sender;
        if (_amountIn > IERC20(_tokenIn).balanceOf(_msgSender)) revert InsufficientBalance();

        _tokenIn = _tokenIn == token0 ? token0 : token1;
        address tokenOut = _tokenIn == token0 ? token1 : token0;
        uint256 reserveIn = _tokenIn == token0 ? reserve0 : reserve1;
        uint256 reserveOut = _tokenIn == token0 ? reserve1 : reserve0;

        require(IERC20(_tokenIn).transferFrom(_msgSender, address(this), _amountIn), TransferFailed());

        uint256 amountOut = LSwapSwopPair.getAmountOut(_amountIn, reserveIn, reserveOut);

        require(IERC20(tokenOut).transfer(_msgSender, amountOut), TransferFailed());

        _tokenIn == token0 ? reserve0 += _amountIn : reserve1 += _amountIn;
        _tokenIn == token0 ? reserve1 -= amountOut : reserve0 -= amountOut;

        emit Swap(_msgSender, _tokenIn, _amountIn, tokenOut, amountOut);

        return amountOut;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISwapSwopPair).interfaceId || super.supportsInterface(interfaceId);
    }
}
