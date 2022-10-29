// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vol.sol";

interface IUniswapV2Router02 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract CounterTest is Test {
    Vol public vol;
    IUniswapV2Router02 public router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public eth_usdc = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public eth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 public Interval = 1 days;
    uint256 public betWindow = 1 hours;
    uint256 public billi = 1_000_000_000 * 10 ** 6;

    function setUp() public {
        vol = new Vol(
            eth_usdc,
            eth,
            usdc,
            Interval,
            betWindow
        );
        deal(usdc, address(this), billi);
        IERC20(usdc).approve(address(vol), type(uint256).max);
        IERC20(usdc).approve(address(router), type(uint256).max);
    }

    function testBet() public {
        vol.bet(1_000, 4);
        vol.bet(1_000, 5);
        swap(1_000_000);
        vm.warp(block.timestamp + 1 days);
        vol.finalizeEpoch();
        uint256 balanceBefore = IERC20(usdc).balanceOf(address(this));
        vol.claim(0);
        uint256 balanceAfter = IERC20(usdc).balanceOf(address(this));
        (uint256 startTime,
        uint256 startPrice,
        uint256 finalPrice,
        uint256 totalUsdc,
        uint256 realizedVol,
        uint256 payOffPerDollar,
        ) = vol.epochs(0);
        console.log(startTime);
        console.log(startPrice);
        console.log(finalPrice);
        console.log(totalUsdc);
        console.log(realizedVol);
        console.log(payOffPerDollar);
    }

    function swap(uint256 amount) public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = eth;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(amount * 10 ** 6, 0, path, address(this), block.timestamp + 10);
    }

    receive() external payable {}
}
