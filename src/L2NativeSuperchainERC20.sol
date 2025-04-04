// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/console2.sol";
import {SuperchainERC20} from "interop-lib/src/SuperchainERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ConstantSumHook} from "src/ConstantSumHook.sol";

interface IRouter {
  function swap(PoolKey memory key, IPoolManager.SwapParams memory params) external payable;
  function manager() external returns (IPoolManager);
}

contract L2NativeSuperchainERC20 is SuperchainERC20 {
  using Strings for string;

  string private NAME;
  string private SYMBOL;
  uint8 private immutable DECIMALS;
  IERC20 public immutable NATIVE_TOKEN;
  PoolKey public key;
  IRouter public router;
  address public hook;

  /// @dev All sqrtPrice calculations are calculated as
  /// sqrtPriceX96 = floor(sqrt(A / B) * 2 ** 96) where A and B are the currency reserves
  uint160 public constant SQRT_PRICE_1_1 = 79_228_162_514_264_337_593_543_950_336;

  event Deposit(address indexed from, uint256 amount);
  event Withdrawal(address indexed to, uint256 amount);

  constructor(address _nativeToken, address _swapRouter) {
    NATIVE_TOKEN = IERC20(_nativeToken);
    NAME = string.concat("SuperWrapped ", NATIVE_TOKEN.name());
    SYMBOL = string.concat("sw", NATIVE_TOKEN.symbol());
    DECIMALS = NATIVE_TOKEN.decimals();
    router = IRouter(_swapRouter);
  }

  function initialize(PoolKey calldata _key, address _hook) public {
    key = _key;
    hook = _hook;
  }

  function name() public view virtual override returns (string memory) {
    return NAME;
  }

  function symbol() public view virtual override returns (string memory) {
    return SYMBOL;
  }

  function decimals() public view override returns (uint8) {
    return DECIMALS;
  }

  // Deposit native tokens to receive wrapped tokens
  function deposit(uint256 _amount) public payable {
    NATIVE_TOKEN.transferFrom(msg.sender, address(this), _amount);
    NATIVE_TOKEN.approve(address(router), _amount);
    IERC20(address(this)).approve(address(hook), _amount);
    // ConstantSumHook(hook).addLiquidity(key, _amount);
    router.swap(
      key,
      IPoolManager.SwapParams({
        zeroForOne: true,
        amountSpecified: int256(_amount),
        sqrtPriceLimitX96: SQRT_PRICE_1_1
      })
    );
    IERC20(address(this)).transfer(msg.sender, _amount);

    emit Deposit(msg.sender, _amount);
  }

  // Withdraw native tokens by burning wrapped tokens
  function withdraw(uint256 amount) public {
    require(balanceOf(msg.sender) >= amount, "Insufficient balance");
    IERC20(address(this)).approve(address(router), amount);
    IERC20(address(this)).transferFrom(msg.sender, address(this), amount);

    router.swap(
      key,
      IPoolManager.SwapParams({
        zeroForOne: false,
        amountSpecified: int256(amount),
        sqrtPriceLimitX96: SQRT_PRICE_1_1
      })
    );

    // _burn(address(router.manager()), amount);
    NATIVE_TOKEN.transfer(msg.sender, amount);
    emit Withdrawal(msg.sender, amount);
  }

  // TODO Add access control
  function mint(address _to, uint256 _amount) public {
    _mint(_to, _amount);
  }

  // TODO Add access control
  function burn(address _from, uint256 _amount) public {
    _burn(_from, _amount);
  }
}
