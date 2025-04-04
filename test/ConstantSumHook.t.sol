// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Fixtures} from "v4-constant-sum/test/utils/Fixtures.sol";
import {L2NativeSuperchainERC20} from "../src/L2NativeSuperchainERC20.sol";
import {ConstantSumHook} from "../src/ConstantSumHook.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract ConstantSumHookTest is Test, Fixtures {
  ConstantSumHook hook;
  Currency superchainToken0;
  Currency nativeToken0;
  L2NativeSuperchainERC20 superchainToken;

  uint256 tokenId;
  int24 tickLower;
  int24 tickUpper;

  function setUp() public {
    // creates the pool manager, utility routers, and test tokens
    deployFreshManagerAndRouters();
    deployMintAndApprove2Currencies();

    deployAndApprovePosm(manager);

    // Create the superchain token
    nativeToken0 = currency0;
    superchainToken =
      new L2NativeSuperchainERC20(Currency.unwrap(nativeToken0), address(swapRouterNoChecks));
    superchainToken0 = Currency.wrap(address(superchainToken));

    // Deploy the hook to an address with the correct flags
    address flags = address(
      uint160(
        Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
          | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
      ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
    );
    bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor
      // arguments from the hook
    deployCodeTo("ConstantSumHook.sol:ConstantSumHook", constructorArgs, flags);
    hook = ConstantSumHook(flags);

    // Create the pool
    key = PoolKey(nativeToken0, superchainToken0, 3000, 60, IHooks(hook));
    manager.initialize(key, SQRT_PRICE_1_1);
    superchainToken.initialize(key, address(hook));
  }

  function _depositNative(uint256 _amount) public {
    // Deposit into super
    MockERC20(Currency.unwrap(nativeToken0)).mint(address(this), _amount);
    IERC20(Currency.unwrap(nativeToken0)).approve(address(superchainToken), _amount);
    superchainToken.deposit(_amount);
  }

  function testFuzz_depositNative(uint256 _amount) public {
    _amount = bound(_amount, 1 wei, 10_000_000_000e18);

    MockERC20(Currency.unwrap(nativeToken0)).mint(address(this), _amount);
    IERC20(Currency.unwrap(nativeToken0)).approve(address(superchainToken), _amount);
    superchainToken.deposit(_amount);

    assertEq(superchainToken.balanceOf(address(this)), _amount);
    assertEq(nativeToken0.balanceOf(address(manager)), _amount);
    assertEq(superchainToken.balanceOf(address(hook)), 0);
    assertEq(nativeToken0.balanceOf(address(hook)), 0);
    assertEq(superchainToken.totalSupply(), _amount);
  }

  function testFuzz_withdrawSuper(uint256 _amount) public {
    _amount = bound(_amount, 1 wei, 10_000_000_000e18);

    uint256 _startBalance = nativeToken0.balanceOf(address(this));
    _depositNative(_amount);
    assertEq(superchainToken.balanceOf(address(this)), _amount);
    superchainToken.approve(address(superchainToken), _amount);
    superchainToken.withdraw(_amount);

    assertEq(superchainToken.balanceOf(address(this)), 0);
    assertEq(nativeToken0.balanceOf(address(this)) - _startBalance, _amount);
    assertEq(nativeToken0.balanceOf(address(manager)), 0);
    assertEq(superchainToken.balanceOf(address(manager)), _amount);
    assertEq(superchainToken.balanceOf(address(hook)), 0);
    assertEq(nativeToken0.balanceOf(address(hook)), 0);
  }

  function testFuzz_SwapNativeForSuper(uint256 _initialNativeDepositAmount, uint256 _swapAmount)
    public
  {
    _swapAmount = bound(_swapAmount, 1 wei, 10_000_000_000e18);
    _initialNativeDepositAmount = bound(_initialNativeDepositAmount, _swapAmount, 10_000_000_000e18);
    address swapper = makeAddr("Swapper");

    uint256 _startBalance = nativeToken0.balanceOf(address(this));
    _depositNative(_initialNativeDepositAmount);
    assertEq(superchainToken.balanceOf(address(this)), _initialNativeDepositAmount);

    vm.startPrank(swapper);
    MockERC20(Currency.unwrap(nativeToken0)).mint(swapper, _swapAmount);
    assertEq(MockERC20(Currency.unwrap(nativeToken0)).balanceOf(swapper), _swapAmount);
    MockERC20(Currency.unwrap(nativeToken0)).approve(address(swapRouterNoChecks), _swapAmount);
    swapRouterNoChecks.swap(
      key,
      IPoolManager.SwapParams({
        zeroForOne: true,
        amountSpecified: int256(_swapAmount),
        sqrtPriceLimitX96: SQRT_PRICE_1_1
      })
    );
    vm.stopPrank();

    assertEq(superchainToken.balanceOf(address(this)), _initialNativeDepositAmount);
    assertEq(nativeToken0.balanceOf(address(this)) - _startBalance, 0);
    assertEq(superchainToken.balanceOf(swapper), _swapAmount);
    assertEq(nativeToken0.balanceOf(swapper), 0);

    assertEq(nativeToken0.balanceOf(address(manager)), _initialNativeDepositAmount + _swapAmount);
    assertEq(superchainToken.balanceOf(address(manager)), 0);
    assertEq(superchainToken.balanceOf(address(hook)), 0);
    assertEq(nativeToken0.balanceOf(address(hook)), 0);
  }

  function test_RvertIf_ModifyingLiquidity() public {
    vm.expectRevert();
    modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
  }
}
