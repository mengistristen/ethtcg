// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface ERC721 {
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    function balanceOf(address _owner) external view returns (uint256);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) external payable;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    function approve(address _approved, uint256 _tokenId) external payable;

    function setApprovalForAll(address _operator, bool _approved) external;

    function getApproved(uint256 _tokenId) external view returns (address);

    function isApprovedForAll(address _owner, address _operator)
        external
        view
        returns (bool);
}

interface ERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface ERC721TokenReceiver {
    function onERC721Recieved(
        address _from,
        address _to,
        uint256 _tokenID,
        bytes memory data
    ) external returns (bytes4);
}

contract Owner {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}

contract CardBase {
    struct Card {
        uint8 cost;
        string name;
    }

    mapping(uint256 => address) cardIdToOwner;
    mapping(address => uint256) ownerCardCount;
    mapping(uint256 => address) cardIdToApprovedAddress;
    mapping(address => mapping(address => bool)) operatorToCanOperateForOwner;
    uint256 totalCards;
    Card[] cards;

    function createCard(
        uint8 _cost,
        string calldata _name,
        address owner
    ) internal returns (uint256) {
        Card memory _card = Card({cost: _cost, name: _name});

        cards.push(_card);
        totalCards++;

        ownerCardCount[owner]++;
        cardIdToOwner[totalCards - 1] = owner;

        return totalCards - 1;
    }
}

contract CardOwnership is CardBase, ERC721, ERC165 {
    string public constant name = "EthTCG";
    string public constant symbol = "ETCG";

    // Constants for supporting interface ERC165
    bytes4 constant InterfaceSignature_ERC165 =
        bytes4(keccak256("supportsInterface(bytes4)"));

    bytes4 constant InterfaceSignature_ERC721 =
        bytes4(keccak256("name()")) ^
            bytes4(keccak256("symbol()")) ^
            bytes4(keccak256("balanceOf(address)")) ^
            bytes4(keccak256("ownerOf(uint256)")) ^
            bytes4(
                keccak256("safeTransferFrom(address,address,uint256,bytes)")
            ) ^
            bytes4(keccak256("safeTransferFrom(address,address,uint256)")) ^
            bytes4(keccak256("transferFrom(address,address,uint256)")) ^
            bytes4(keccak256("approve(address, uint256)")) ^
            bytes4(keccak256("setApprovalForAll(address,bool)")) ^
            bytes4(keccak256("getApproved(uint256)")) ^
            bytes4(keccak256("isApprovedForAll(address,address)"));

    // Support for ERC165
    function supportsInterface(bytes4 interfaceID)
        external
        pure
        override
        returns (bool)
    {
        return ((interfaceID == InterfaceSignature_ERC721) ||
            (interfaceID == InterfaceSignature_ERC165));
    }

    modifier onlyValidTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) {
        require(
            (msg.sender == cardIdToOwner[_tokenId]) ||
                (msg.sender == cardIdToApprovedAddress[_tokenId]) ||
                (operatorToCanOperateForOwner[msg.sender][_from])
        );
        require(_from == cardIdToOwner[_tokenId]);
        require(_to != address(0));
        require(_tokenId < totalCards);
        _;
    }

    function balanceOf(address _owner)
        external
        view
        override
        returns (uint256)
    {
        require(_owner != address(0));
        return ownerCardCount[_owner];
    }

    function ownerOf(uint256 _tokenId)
        external
        view
        override
        returns (address)
    {
        address owner = cardIdToOwner[_tokenId];

        require(owner != address(0));
        return owner;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) external payable override onlyValidTransfer(_from, _to, _tokenId) {
        cardIdToOwner[_tokenId] = _to;
        ownerCardCount[_from]--;
        ownerCardCount[_to]++;

        // Retrieve _to address code size
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_to)
        }

        // if _to has code, it is a contract
        // check that it implements the ERC721TokenReciever interface
        if (codeSize > 0) {
            ERC721TokenReceiver toContract = ERC721TokenReceiver(_to);

            require(
                toContract.onERC721Recieved(_from, _to, _tokenId, data) ==
                    bytes4(
                        keccak256(
                            "onERC721Recieved(address,address,uint256,bytes)"
                        )
                    )
            );
        }

        emit Transfer(_from, _to, _tokenId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable override {
        this.safeTransferFrom(_from, _to, _tokenId, "");
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable override onlyValidTransfer(_from, _to, _tokenId) {
        cardIdToOwner[_tokenId] = _to;
        ownerCardCount[_from]--;
        ownerCardCount[_to]++;

        emit Transfer(_from, _to, _tokenId);
    }

    function approve(address _approved, uint256 _tokenId)
        external
        payable
        override
    {
        require(
            (msg.sender == cardIdToOwner[_tokenId]) ||
                operatorToCanOperateForOwner[msg.sender][
                    cardIdToOwner[_tokenId]
                ]
        );
        cardIdToApprovedAddress[_tokenId] = _approved;

        emit Approval(cardIdToOwner[_tokenId], _approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved)
        external
        override
    {
        operatorToCanOperateForOwner[_operator][msg.sender] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId)
        external
        view
        override
        returns (address)
    {
        require(_tokenId < totalCards);
        return cardIdToApprovedAddress[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator)
        external
        view
        override
        returns (bool)
    {
        return operatorToCanOperateForOwner[_operator][_owner];
    }
}

contract CardMinting is CardOwnership, Owner {
    uint256 public constant maxPromoCards = 100;
    uint256 public currentPromoCards = 0;

    function mintPromoCard(
        uint8 _cost,
        string calldata _name,
        address _owner
    ) public onlyOwner {
        require(currentPromoCards < maxPromoCards);

        createCard(_cost, _name, _owner);
        currentPromoCards++;
    }
}
