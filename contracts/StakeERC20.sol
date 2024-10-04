// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

// import "./IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract StakeERC20 {
    // Custom Errors
    error CannotSendZeroValue();
    error FailedTransfer();
    error InsufficientContractBalance();
    error InsufficientFunds();
    error MaxDurationExceeded();
    error NotOwner();
    error StakingPeriodNotOver();
    error StakingRewardsAlreadyClaimed();
    error ZeroAddressDetected();

    address private _owner;
    IERC20 public token;

    uint256 public constant MAX_DURATION = 365 days;
    uint256 public constant SECONDS_IN_YEAR = MAX_DURATION * 24 * 60 * 60;
    uint64 public constant PRECISION_FACTOR = 1e18; // Scaling factor for precision
    uint8 public constant INTEREST_RATE = 4; // Representing 4% as4

    struct Stake {
        uint256 stakeAmount; // in lowest denomination (1e18)
        uint256 stakeReward; // in lowest denomination (1e18)
        uint256 startTime; // in seconds
        uint256 vestingPeriod; // in seconds
        address staker;
        bool isStaked;
        bool isMature;
    }

    mapping(address => Stake) userStakes;

    // Events
    event DepositSuccessful(
        address indexed sender,
        uint256 amount,
        uint256 timeAtDeposit
    );
    event StakeSuccessful(
        address indexed staker,
        uint256 amount,
        uint256 timeAtStaking
    );
    event WithdrawSuccessful(
        address indexed withdrawer,
        uint256 amount,
        uint256 timeAtWithdrawal
    );

    constructor(address _tokenAddress) {
        _owner = msg.sender;
        token = IERC20(_tokenAddress);
    }

    function depositTokens(uint256 _amount) external {
        // Check for zero address and zero amount
        if (msg.sender == address(0)) {
            revert ZeroAddressDetected();
        }

        if (_amount <= 0) {
            revert CannotSendZeroValue();
        }

        // Deposit Ether into contract address to fund rewards
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert FailedTransfer();
        }

        // Trigger successful Deposit event
        emit DepositSuccessful(msg.sender, _amount, block.timestamp);
    }

    function stakeTokens(uint256 _amount, uint256 _duration) external {
        // Perform checks and revert errors as due
        if (msg.sender == address(0)) {
            revert ZeroAddressDetected();
        }

        if (userStakes[msg.sender].isStaked) {
            revert StakingPeriodNotOver();
        }

        if (_amount <= 0) {
            revert CannotSendZeroValue();
        }

        if (_duration > MAX_DURATION) {
            revert MaxDurationExceeded();
        }

        // Create new stake variable in memory for user and assign properties
        Stake memory newStake;

        newStake.staker = msg.sender;
        newStake.stakeAmount = _amount;
        newStake.startTime = block.timestamp;
        newStake.vestingPeriod = _duration;
        newStake.isStaked = true;

        // Deposit tokens into contract staking pool
        if (token.balanceOf(msg.sender) < _amount) {
            revert InsufficientFunds();
        }

        // Transfer user's approved stake amount to contract balance
        token.transferFrom(msg.sender, address(this), _amount);

        // Push newly created stake to stakes array in storage
        userStakes[msg.sender] = newStake;

        // Trigger successful Staking event
        emit StakeSuccessful(msg.sender, _amount, block.timestamp);
    }

    function withdrawStake() external {
        // Perform sanity check
        if (msg.sender == address(0)) {
            revert ZeroAddressDetected();
        }

        // Create storage variable to hold and manipulate Stake struct
        Stake storage st = userStakes[msg.sender];

        // Calculate user's total staking period
        uint256 stakingPeriod = st.startTime + st.vestingPeriod;

        // Catch and throw all withdrawal errors
        if (st.stakeAmount <= 0) {
            revert CannotSendZeroValue();
        }

        if (msg.sender != st.staker) {
            revert NotOwner();
        }

        if (block.timestamp < stakingPeriod) {
            revert StakingPeriodNotOver();
        }

        if (st.isMature) {
            revert StakingRewardsAlreadyClaimed();
        }

        // Calculate staking reward
        st.stakeReward = _calculateReward(stakingPeriod);
        uint256 matureStake = st.stakeAmount + st.stakeReward;

        // Check contract balance before transferring money
        if (matureStake > token.balanceOf(address(this))) {
            revert InsufficientContractBalance();
        }

        // Toggle booleans in Stake struct to false to indicate matured stake
        st.isMature = true;
        st.isStaked = false;

        // Transfer stake + reward to user's address
        token.transfer(msg.sender, matureStake);

        // Trigger successful Withdrawal event
        emit WithdrawSuccessful(msg.sender, matureStake, block.timestamp);
    }

    function _calculateReward(
        uint256 _duration
    ) private view returns (uint256) {
        //
        Stake storage st = userStakes[msg.sender];
        uint256 principal = st.stakeAmount;
        uint256 stakingDuration = _duration;

        // uint256 stakingReward = (principal * INTEREST_RATE * stakingDuration) /
        //     (SECONDS_IN_YEAR * 100);

        uint256 stakingReward = (principal *
            INTEREST_RATE *
            stakingDuration *
            PRECISION_FACTOR) / (SECONDS_IN_YEAR * 100 * PRECISION_FACTOR);

        return stakingReward;
    }

    function getMyStake() external view returns (Stake memory) {
        return userStakes[msg.sender];
    }

    function getUserStake(
        address _staker
    ) external view returns (Stake memory) {
        _onlyOwner();
        return userStakes[_staker];
    }

    function getUserRewardSoFar() external view returns (uint256) {
        Stake storage st = userStakes[msg.sender];
        uint256 timeVested = block.timestamp - st.startTime;

        uint256 reward = _calculateReward(timeVested);
        return reward;
    }

    function getTotalStakeAmount() external view returns (uint256) {
        _onlyOwner();
        return token.balanceOf(address(this));
    }

    function _onlyOwner() private view {
        require(msg.sender == _owner);
    }
}
