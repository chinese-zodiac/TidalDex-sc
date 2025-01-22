// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Credit to Wex/WaultSwap, Synthetix
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20MintableBurnable} from "./interfaces/IERC20MintableBurnable.sol";
import {IFarmMaster} from "./interfaces/IFarmMaster.sol";
//import "hardhat/console.sol";

//Fixed pool yield + flexible lp yields.
//Emission rate is set such that pid0, the yieldToken->yieldToken pool, earns a fixed apr.
//Routable allows for owner to set a router contract that allows users to 1 click claim
//or to use other defi building blocks to construct more complex transactions
contract TidalDexFarmMaster is IFarmMaster, Ownable {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint16 depositTaxBasis;
        uint16 withdrawTaxBasis;
        uint32 allocPoint;
        uint256 lastRewardTimestamp;
        uint256 accYtknPerShare;
        uint256 totalDeposit;
    }

    IERC20MintableBurnable public immutable ytkn; //yield token
    uint256 public ytknPerSecond;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint32 public totalAllocPoint = 0;
    uint256 public startTimestamp;
    uint256 public baseAprBasis = 500; //5.00%

    address public router;
    address public treasury;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event UpdateYtknPerSecond(uint256 amount);

    constructor(
        uint256 _startTimestamp,
        IERC20MintableBurnable _ytkn,
        address _treasury
    ) Ownable(_treasury) {
        if (_startTimestamp == 0) {
            startTimestamp = block.timestamp;
        } else {
            startTimestamp = _startTimestamp;
        }
        ytkn = _ytkn;
        treasury = _treasury;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public pure returns (uint256) {
        return _to - _from;
    }

    function add(
        uint32 _allocPoint,
        uint16 _depositTaxBasis,
        uint16 _withdrawTaxBasis,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp
            ? block.timestamp
            : startTimestamp;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                depositTaxBasis: _depositTaxBasis,
                withdrawTaxBasis: _withdrawTaxBasis,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accYtknPerShare: 0,
                totalDeposit: 0
            })
        );
    }

    function set(
        uint256 _pid,
        uint32 _allocPoint,
        uint16 _depositTaxBasis,
        uint16 _withdrawTaxBasis,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositTaxBasis = _depositTaxBasis;
        poolInfo[_pid].withdrawTaxBasis = _withdrawTaxBasis;
    }

    function pendingYtkn(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accYtknPerShare = pool.accYtknPerShare;
        uint256 totalDeposit = pool.totalDeposit;
        if (block.timestamp > pool.lastRewardTimestamp && totalDeposit != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardTimestamp,
                block.timestamp
            );
            uint256 ytknReward = (multiplier *
                ytknPerSecond *
                pool.allocPoint) / totalAllocPoint;
            accYtknPerShare =
                accYtknPerShare +
                ((ytknReward * 1e12) / totalDeposit);
        }
        return
            ((user.amount * accYtknPerShare) / 1e12) +
            user.pendingRewards -
            user.rewardDebt;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];

        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 totalDeposit = pool.totalDeposit;
        if (totalDeposit == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(
            pool.lastRewardTimestamp,
            block.timestamp
        );

        uint256 ytknReward = (multiplier * ytknPerSecond * pool.allocPoint) /
            totalAllocPoint;

        ytkn.mint(address(this), ytknReward);

        pool.accYtknPerShare =
            pool.accYtknPerShare +
            ((ytknReward * 1e12) / totalDeposit);
        pool.lastRewardTimestamp = block.timestamp;
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        _deposit(_pid, _amount, true, msg.sender, msg.sender);
    }

    function depositRoutable(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards,
        address _account,
        address _assetSender
    ) public {
        require(msg.sender == router);
        _deposit(_pid, _amount, _withdrawRewards, _account, _assetSender);
    }

    function _deposit(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards,
        address _account,
        address _assetSender
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_account];

        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = ((user.amount * pool.accYtknPerShare) / 1e12) -
                user.rewardDebt;

            if (pending > 0) {
                user.pendingRewards = user.pendingRewards + pending;

                if (_withdrawRewards) {
                    safeYtknTransfer(_account, user.pendingRewards);
                    emit Claim(_account, _pid, user.pendingRewards);
                    user.pendingRewards = 0;
                }
            }
        }
        if (_amount > 0) {
            uint256 fee = (_amount * pool.depositTaxBasis) / 10000;
            require(
                pool.lpToken.transferFrom(
                    address(_assetSender),
                    address(this),
                    _amount - fee
                ),
                "FMR: Transfer failed"
            );
            require(
                pool.lpToken.transferFrom(address(_assetSender), treasury, fee),
                "FMR: Transfer fee failed"
            );

            pool.totalDeposit = pool.totalDeposit + _amount - fee;
            user.amount = user.amount + _amount - fee;
        }
        user.rewardDebt = (user.amount * pool.accYtknPerShare) / 1e12;
        if (_pid == 0) {
            _updateYtknPerSecond();
        }
        emit Deposit(_account, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        _withdraw(_pid, _amount, true, msg.sender, msg.sender);
    }

    function withdrawRoutable(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards,
        address _account,
        address _assetReceiver
    ) public {
        require(msg.sender == router);
        _withdraw(_pid, _amount, _withdrawRewards, _account, _assetReceiver);
    }

    function _withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards,
        address _account,
        address _assetReceiver
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_account];

        require(user.amount >= _amount, "FMR: balance too low");
        updatePool(_pid);
        uint256 pending = ((user.amount * pool.accYtknPerShare) / 1e12) -
            user.rewardDebt;
        if (pending > 0) {
            user.pendingRewards = user.pendingRewards + pending;

            if (_withdrawRewards) {
                safeYtknTransfer(_account, user.pendingRewards);
                emit Claim(_account, _pid, user.pendingRewards);
                user.pendingRewards = 0;
            }
        }
        if (_amount > 0) {
            uint256 fee = (_amount * pool.withdrawTaxBasis) / 10000;
            pool.totalDeposit = pool.totalDeposit - _amount;
            user.amount = user.amount - _amount;
            require(
                pool.lpToken.transfer(_assetReceiver, _amount - fee),
                "FMR: Transfer failed"
            );
            require(
                pool.lpToken.transfer(treasury, fee),
                "FMR: Transfer fee failed"
            );
            if (_pid == 0) {
                _updateYtknPerSecond();
            }
        }
        user.rewardDebt = (user.amount * pool.accYtknPerShare) / 1e12;
        emit Withdraw(_account, _pid, _amount);
    }

    function _updateYtknPerSecond() internal {
        //Set ytknPerSecond based on the first pool's ytkn stake.
        ytknPerSecond =
            (poolInfo[0].totalDeposit * baseAprBasis * totalAllocPoint) /
            poolInfo[0].allocPoint /
            10000 /
            365.25 days;
    }

    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        address assetReceiver = msg.sender;
        uint256 fee = (user.amount * pool.withdrawTaxBasis) / 10000;
        require(
            pool.lpToken.transfer(assetReceiver, user.amount - fee),
            "FMR: Transfer failed"
        );
        require(
            pool.lpToken.transfer(treasury, fee),
            "FMR: Transfer fee failed"
        );
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        pool.totalDeposit = pool.totalDeposit - user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.pendingRewards = 0;
        if (_pid == 0) {
            _updateYtknPerSecond();
        }
    }

    function claim(uint256 _pid) public {
        _claim(_pid, msg.sender);
    }

    function claimRoutabale(address _for, uint256 _pid) public {
        require(msg.sender == router);
        _claim(_pid, _for);
    }

    function _claim(uint256 _pid, address _for) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_for];
        updatePool(_pid);
        uint256 pending = (user.amount * pool.accYtknPerShare) /
            1e12 -
            user.rewardDebt;
        if (pending > 0 || user.pendingRewards > 0) {
            user.pendingRewards = user.pendingRewards + pending;
            safeYtknTransfer(_for, user.pendingRewards);
            emit Claim(_for, _pid, user.pendingRewards);
            user.pendingRewards = 0;
        }
        user.rewardDebt = (user.amount * pool.accYtknPerShare) / 1e12;
    }

    function safeYtknTransfer(address _to, uint256 _amount) internal {
        uint256 ytknBal = ytkn.balanceOf(address(this));
        if (_amount > ytknBal) {
            ytkn.transfer(_to, ytknBal);
        } else {
            ytkn.transfer(_to, _amount);
        }
    }

    function setRouter(address _router) public onlyOwner {
        router = _router;
    }

    function setTreasury(address _to) public onlyOwner {
        treasury = _to;
    }

    function setBaseAprBasis(uint256 _to) public onlyOwner {
        baseAprBasis = _to;
    }
}
