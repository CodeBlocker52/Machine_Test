// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract StakingPool {
    IERC20 public stakingToken;
    uint256 public poolDistributionAmount;
    uint256 public poolDuration;
    uint256 public lockinDuration;
    uint256 public startTime;
    uint256 public totalStaked;
    uint256 public totalRewardClaimed;
    uint256 public activeStakersCount;
    uint256 public lastRewardTime;
    uint256 public accRewardPerShare;

    struct Staker {
        uint256 amountStaked;
        uint256 rewardDebt;
        uint256 rewardClaimed;
        uint256 stakeTimestamp;
        bool isActive;
    }

    mapping(address => Staker) public stakers;
    address[] public allStakers;
    address[] public activeStakers;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(
        address _stakingToken,
        uint256 _poolDistributionAmount,
        uint256 _poolDuration,
        uint256 _lockinDuration
    )  {
        stakingToken = IERC20(_stakingToken);
        poolDistributionAmount = _poolDistributionAmount;
        poolDuration = _poolDuration;
        lockinDuration = _lockinDuration;
        startTime = block.timestamp;
        lastRewardTime = block.timestamp;
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "Cannot stake 0 tokens");
        require(block.timestamp < startTime + poolDuration * 1 days, "Staking period is over");

        updatePool();

        Staker storage staker = stakers[msg.sender];
        if (staker.amountStaked == 0) {
            allStakers.push(msg.sender);
        }
        if (!staker.isActive) {
            activeStakers.push(msg.sender);
            activeStakersCount++;
        }

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        staker.amountStaked += _amount;
        staker.rewardDebt = (staker.amountStaked * accRewardPerShare) / 1e18;
        staker.stakeTimestamp = block.timestamp;
        staker.isActive = true;
        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    function unstake() external {
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked > 0, "No tokens to unstake");
        require(block.timestamp >= staker.stakeTimestamp + lockinDuration * 1 days, "Tokens are locked");

        updatePool();

        uint256 amount = staker.amountStaked;
        uint256 reward = pendingReward(msg.sender);
        staker.rewardClaimed += reward;
        totalRewardClaimed += reward;
        staker.amountStaked = 0;
        staker.rewardDebt = 0;
        staker.isActive = false;
        totalStaked -= amount;
        activeStakersCount--;

        stakingToken.transfer(msg.sender, amount + reward);

        emit Unstaked(msg.sender, amount);
        emit RewardClaimed(msg.sender, reward);
    }

    function claimReward() external {
        updatePool();
        Staker storage staker = stakers[msg.sender];
        uint256 reward = pendingReward(msg.sender);
        require(reward > 0, "No rewards to claim");

        staker.rewardClaimed += reward;
        totalRewardClaimed += reward;
        staker.rewardDebt = (staker.amountStaked * accRewardPerShare) / 1e18;

        stakingToken.transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function updatePool() public {
        if (block.timestamp <= lastRewardTime) {
            return;
        }
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp - lastRewardTime;
        uint256 dailyDistributionAmount = poolDistributionAmount / poolDuration;
        uint256 tokenReward = (dailyDistributionAmount * multiplier) / 1 days;
        accRewardPerShare += (tokenReward * 1e18) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    function pendingReward(address _user) public view returns (uint256) {
        Staker storage staker = stakers[_user];
        if (staker.amountStaked == 0) {
            return 0;
        }
        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 multiplier = block.timestamp - lastRewardTime;
            uint256 dailyDistributionAmount = poolDistributionAmount / poolDuration;
            uint256 tokenReward = (dailyDistributionAmount * multiplier) / 1 days;
            _accRewardPerShare += (tokenReward * 1e18) / totalStaked;
        }
        return (staker.amountStaked * _accRewardPerShare) / 1e18 - staker.rewardDebt;
    }

    function getCurrentHourlyRewardEmission() external view returns (uint256) {
        return poolDistributionAmount / (poolDuration * 24);
    }

    function getTotalPoolAmountLeft() external view returns (uint256) {
        return poolDistributionAmount - totalRewardClaimed;
    }

    function getCountOfActiveStakers() external view returns (uint256) {
        return activeStakersCount;
    }

    function getListOfActiveStakers() external view returns (address[] memory) {
        return activeStakers;
    }

    function getListOfAllStakers() external view returns (address[] memory) {
        return allStakers;
    }

    function getTotalTokensStaked() external view returns (uint256) {
        return totalStaked;
    }

    function getStakerDetails(address _staker) external view returns (uint256, uint256, address, uint256) {
        Staker storage staker = stakers[_staker];
        return (staker.amountStaked, staker.rewardClaimed, _staker, staker.stakeTimestamp);
    }
}
