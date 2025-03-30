// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
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

    // Seed liquidity
    // IERC20(Currency.unwrap(superchainToken0)).approve(address(hook), 1000e18);
    // IERC20(Currency.unwrap(nativeToken0)).approve(address(hook), 1000e18);
    // hook.addLiquidity(key, 1000e18);
  }

  function _depositNative(uint256 _amount) public {
	// Deposit into super
    MockERC20(Currency.unwrap(nativeToken0)).mint(address(this), _amount);
    IERC20(Currency.unwrap(nativeToken0)).approve(address(superchainToken), _amount);
    superchainToken.deposit(_amount);
  }

  function test_depositNative(bool zeroForOne /*, uint256 amount*/) public {
    //amount = bound(amount, 1 wei, 1000e18);
    uint256 amount = 1;

    MockERC20(Currency.unwrap(nativeToken0)).mint(address(this), amount);
    IERC20(Currency.unwrap(nativeToken0)).approve(address(superchainToken), amount);
    superchainToken.deposit(amount);

    assertEq(superchainToken.balanceOf(address(this)), amount);
    assertEq(nativeToken0.balanceOf(address(manager)), amount);
    assertEq(superchainToken.balanceOf(address(hook)), 0);
    assertEq(nativeToken0.balanceOf(address(hook)), 0);
  }

  function test_withdrawSuper(bool zeroForOne /*, uint256 amount*/) public {
    //amount = bound(amount, 1 wei, 1000e18);
    uint256 amount = 1;

	uint256 _startBalance = nativeToken0.balanceOf(address(this));
	_depositNative(amount);
    assertEq(superchainToken.balanceOf(address(this)), amount);
	superchainToken.approve(address(superchainToken), amount);
	superchainToken.withdraw(amount);

    assertEq(superchainToken.balanceOf(address(this)), 0);
    assertEq(nativeToken0.balanceOf(address(this)) - _startBalance, 1);
    assertEq(nativeToken0.balanceOf(address(manager)), 0);
    assertEq(superchainToken.balanceOf(address(manager)), 0);
    // assertEq(nativeToken0.balanceOf(address(address(this))), 0);
    assertEq(superchainToken.balanceOf(address(hook)), 0);
    assertEq(nativeToken0.balanceOf(address(hook)), 0);
  }

  //   function test_exactOutput(bool zeroForOne, uint256 amount) public {
  //     amount = bound(amount, 1 wei, 1000e18);
  //     uint256 balance0Before = superchainToken0.balanceOfSelf();
  //     uint256 balance1Before = nativeToken0.balanceOfSelf();

  //     swap(key, zeroForOne, int256(amount), ZERO_BYTES);

  //     uint256 balance0After = superchainToken0.balanceOfSelf();
  //     uint256 balance1After = nativeToken0.balanceOfSelf();

  //     if (zeroForOne) {
  //       // paid token0
  //       assertEq(balance0Before - balance0After, amount);

  //       // received token1
  //       assertEq(balance1After - balance1Before, amount);
  //     } else {
  //       // paid token1
  //       assertEq(balance1Before - balance1After, amount);

  //       // received token0
  //       assertEq(balance0After - balance0Before, amount);
  //     }
  //   }

  // function test_no_v4_liquidity() public {
  //   vm.expectRevert();
  //   modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
  // }
}
