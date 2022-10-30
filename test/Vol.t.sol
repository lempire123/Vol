// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.0 <0.9.0;

pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import {UniswapV3SwapExamples} from "./UniswapV3SwapExamples.sol";
import "../src/Vol.sol";

interface IUniswapV2Router02 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface UniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract VolTest is Test {
    Vol public vol;
    UniswapV3SwapExamples public uni;
    // IUniswapV2Router02 public router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public eth_usdc = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public eth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public owner = address(16);
    uint256 public Interval = 1 days;
    uint256 public betWindow = 1 hours;
    uint256 public billi = 1_000_000_000 * 10 ** 6;
    uint24 public fee = 500;

    function setUp() public {
        vol = new Vol(
            factory,
            eth,
            usdc,
            fee,
            owner,
            Interval,
            betWindow
        );
        uni = new UniswapV3SwapExamples();
        deal(usdc, address(this), type(uint256).max);
        IERC20(usdc).approve(address(vol), type(uint256).max);
        // IERC20(usdc).approve(address(router), type(uint256).max);
        // IERC20(usdc).approve(address(routerV3), type(uint256).max);
        IERC20(usdc).approve(address(uni), type(uint256).max);
    }

    function testBet() public {
        vol.bet(1_000, 5);
        vol.bet(1_000, 5);
        vol.bet(1_000, 5);
        vol.bet(1_000, 5);
        vm.warp(block.timestamp + 1 hours);
        vol.setStartPrice();
        // swapV3(1_000_000);
        vm.warp(block.timestamp + 23 hours);
        swapV3(1_000_000);
        vm.warp(block.timestamp + 60);
        vol.finalizeEpoch();
        (
            uint256 startTime,
            uint256 startPrice,
            uint256 finalPrice,
            uint256 totalUsdc,
            uint256 realizedVol,
            uint256 payOffPerDollar,
        ) = vol.epochs(0);
        emit log_named_uint("startTime", startTime);
        emit log_named_uint("startPrice", startPrice / 10 ** 6);
        emit log_named_uint("finalPrice", finalPrice / 10 ** 6);
        emit log_named_uint("totalUsdc", totalUsdc);
        emit log_named_uint("realizedVol", realizedVol);
        emit log_named_uint("payOffPerDollar", payOffPerDollar);
        console.log(IERC20(eth).balanceOf(address(this)) / 10 ** 18);
    }

    function swapV3(uint256 amount) public {
        uni.swapExactInputSingleHop(usdc, eth, 500, amount * 10 ** 6);
    }

    receive() external payable {}
}
