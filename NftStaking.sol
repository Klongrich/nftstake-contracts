// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
}

interface IERC721 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

contract Staking is IERC20 {
    uint256 public total_nfts_staked;
    uint256 public total_erc20_created;

    address owner;
    uint256 private StakerIDCount;

    struct Depositer {
        uint256 id;
        uint256[] tokenIDs;
        uint256[] timeStaked;
        uint256 rewards;
        bool registered;
    }

    mapping(address => Depositer) public DepositerInfo;

    IERC721 nftContract;

    //ERC20 Stuff
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name = "NftStakingContract";
    string public symbol = "NSC";
    uint8 public decimals = 18;
    uint256 public totalSupply = 100000000000000000000000000;
    uint256 private totalSupplyTracker = 100000000000000000000000000;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only callable by Owner");
        _;
    }

    constructor(address _nftAddress) public {
        owner = msg.sender;
        total_nfts_staked = 0;
        total_erc20_created = 0;
        StakerIDCount = 0;
        nftContract = IERC721(_nftAddress);
    }

    function stake_nfts(uint256[] memory _tokenIDs) public returns (bool) {
        require(msg.sender != address(0), "Sender is null");

        address _sender = msg.sender;

        if (DepositerInfo[_sender].registered != true) {
            DepositerInfo[_sender].registered = true;
            DepositerInfo[_sender].id = getCount();

            _incrementCounter();
        }

        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            require(
                nftContract.ownerOf(_tokenIDs[i]) == _sender,
                "Staker does not have this tokenID"
            );

            nftContract.transferFrom(_sender, address(this), _tokenIDs[i]);

            DepositerInfo[_sender].tokenIDs.push(_tokenIDs[i]);
            DepositerInfo[_sender].timeStaked.push(block.timestamp);

            total_nfts_staked += 1;
        }
        return (true);
    }

    function _check_ownership(uint256 _tokenID, address _staker)
        internal
        returns (bool)
    {
        for (uint256 i = 0; i < DepositerInfo[_staker].tokenIDs.length; i++) {
            if (DepositerInfo[_staker].tokenIDs[i] == _tokenID) {
                total_nfts_staked -= 1;

                DepositerInfo[_staker].tokenIDs[i] = DepositerInfo[_staker]
                    .tokenIDs[DepositerInfo[_staker].tokenIDs.length - 1];
                DepositerInfo[_staker].tokenIDs.pop();

                return (true);
            }
        }
        return (false);
    }

    function unstake_nfts(address payable _staker, uint256[] memory _tokenIDs)
        public
        returns (bool)
    {
        require(msg.sender != address(0), "Sender is null");
        require(msg.sender == _staker, "Caller is not staker");
        require(
            DepositerInfo[msg.sender].registered == true,
            "Staker Is not Registered"
        );

        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            if (_check_ownership(_tokenIDs[i], _staker)) {
                nftContract.transferFrom(address(this), _staker, _tokenIDs[i]);
            }
        }

        if (DepositerInfo[_staker].tokenIDs.length <= 0) {
            DepositerInfo[_staker].registered = false;
        }
        return (true);
    }

    //Have rewards tabel for token IDs.
    function _calculateReward(uint256 _tokenID)
        internal
        pure
        returns (uint256)
    {
        if (_tokenID < 1000) {
            return (1);
        } else if (_tokenID > 1000 && _tokenID < 2000) {
            return (2);
        } else {
            return (3);
        }
    }

    // 86400 -> unix-time one day is
    // 100 -> coins per day that you would want to pay out.
    function _calculatePayOut(uint256 _tokenID, uint256 _timeStaked)
        public
        view
        returns (uint256)
    {
        if (block.timestamp - _timeStaked <= 10) {
            return (0);
        } else {
            return
                ((((block.timestamp - _timeStaked) / 10) * 10) *
                    _calculateReward(_tokenID)) * 100000000000000000;
        }
    }

    function claim_coins(address payable _staker) public returns (bool) {
        require(msg.sender == _staker, "Caller is not Staker");
        require(
            DepositerInfo[_staker].registered == true,
            "Staker is not regisiter"
        );

        uint256 payout_amount = 0;

        for (uint256 i = 0; i < DepositerInfo[_staker].tokenIDs.length; i++) {
            payout_amount += _calculatePayOut(
                DepositerInfo[_staker].tokenIDs[i],
                DepositerInfo[_staker].timeStaked[i]
            );
            DepositerInfo[_staker].timeStaked[i] = block.timestamp;
        }

        if (payout_amount > totalSupplyTracker) {
            return (false);
        }

        _mint(_staker, payout_amount);
        total_erc20_created += payout_amount;

        return (true);
    }

    function _mint(address _to, uint256 _amount) internal returns (bool) {
        require(totalSupplyTracker - _amount >= 0, "Minting Over Total Supply");

        balanceOf[_to] += _amount;
        totalSupplyTracker -= _amount;

        emit Transfer(address(0), _to, _amount);
        return (true);
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        require(_spender != address(0), "Address is Null");
        require(balanceOf[msg.sender] >= _value, "Insuffectin Funds / Coins");

        allowance[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return (true);
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insuffectin Funds / Coins");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return (true);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        require(_value <= allowance[_from][_to], "Transaction is not Approved");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(_from, _to, _value);
        return (true);
    }

    function getCurrentAmountStaked(address _staker)
        public
        view
        returns (uint256)
    {
        return (DepositerInfo[_staker].tokenIDs.length);
    }

    function getTokenID(address _staker, uint256 _index)
        public
        view
        returns (uint256)
    {
        return (DepositerInfo[_staker].tokenIDs[_index]);
    }

    function getDepositTimeByIndex(address _staker, uint256 _index)
        public
        view
        returns (uint256)
    {
        return (DepositerInfo[_staker].timeStaked[_index]);
    }

    function getBlockTimestamp() public view returns (uint256) {
        return (block.timestamp);
    }

    function _incrementCounter() internal {
        StakerIDCount += 1;
    }

    function _decrementCounter() internal {
        StakerIDCount -= 1;
    }

    function getCount() public view returns (uint256) {
        return StakerIDCount;
    }
}
