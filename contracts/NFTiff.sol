// SPDX-License-Identifier: MIT

// @title: NFTiff
// @author: Tiffany Team

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface ICryptoPunks {
    function punkIndexToAddress(uint256) external view returns (address);
}

contract NFTiff is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using ECDSA for bytes32;

    string public notRevealedUri;
    mapping(uint256 => string) private _tokenURIs;

    uint256 public cost = 30 ether;
    uint256 public maxSupply = 500;
    uint256 public maxMintAmount = 2;
    bool public presaleActive = false;
    bool public publicSaleActive = false;
    bool public paused = false;
    bool public revealed = false;
    bool public isKycRequired = true;
    address private signer; // signer to make signature
    mapping(address => uint256) public whitelistMinted; // address => amount
    mapping(address => bool) whitelistedAddresses;
    mapping(address => bool) blacklistedAddresses;
    address public immutable punksContract; // mainnet punks - 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB

    uint256 public totalClaimed;
    mapping(uint256 => ClaimInfo) public claimInfo; // claimId => ClaimInfo
    mapping(uint256 => uint256) public nftiffClaims; // nftiffId => claimId
    mapping(uint256 => uint256) public punkClaims; // punkId => claimId

    /** DATA STRUCTURE */
    struct ClaimInfo {
        uint256 punkId;
        uint256 nftiffId;
        uint256 timestamp;        
        address claimer;
    }

    /** EVENTS */
    event TokenURIUpdated(uint256 indexed tokenId, string uri);
    event NFTiffMinted(address indexed to, uint256 indexed tokenId);
    event Claimed(uint256 claimId, address indexed to, uint256 punkId, uint256 nftiffId, uint256 timestamp);
    event UsersBlacklisted(address[] users);
    event UsersWhitelisted(address[] users);
    event SignerChanged(address signer);
    event KycRequireChanged(bool kycRequired);
    event PublicSaleStatusChanged(bool isActive);
    event PresaleStatusChanged(bool isActive);
    event MaxSupplyChanged(uint256 maxSupply);
    event NotRevealedUriChanged(string uri);
    event MaxMintAmountChanged(uint256 amount);
    event CostChanged(uint256 cost);
    event Paused(bool isPaused);
    event Revealed();

    /** METHODS */
    constructor(string memory _initNotRevealedUri, address punksContract_) ERC721("NFTiff", "NFTiff") {
        setNotRevealedURI(_initNotRevealedUri);
        signer = msg.sender;
        punksContract = punksContract_;
    }
    
    //MODIFIERS
    modifier notPaused {
         require(!paused, "Contract paused");
         _;
    }

    modifier notBlacklisted(address user_) {
         require(!blacklistedAddresses[user_], "Blacklisted user");
         _;
    }

    // INTERNAL

    function presaleValidations(bytes memory _signature) internal view {
        require(whitelistedAddresses[msg.sender] == true, "Not whitelisted user");

        if(isKycRequired) {
            bytes32 hash = keccak256(abi.encodePacked("kyc-approved", msg.sender));
            address signer_ = hash.toEthSignedMessageHash().recover(_signature);
            require(signer_ == signer, "Kyc not approved");
        }
    }

    //MINT
    function mint1(uint256 _mintAmount, bytes memory _signature) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(presaleActive, "Sale has not started yet");
        require(msg.value >= cost * _mintAmount, "Insufficient funds");
        require(_mintAmount > 0, "Need to mint at least 1 NFT");
        require(_mintAmount + whitelistMinted[msg.sender] <= maxMintAmount, "Max mint amount exceeded");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "Max NFT limit exceeded");

        presaleValidations(_signature);

        whitelistMinted[msg.sender] += _mintAmount;
        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
            emit NFTiffMinted(msg.sender, supply + i);
        }
    }
    
    function gift(uint256 _mintAmount, address destination) public onlyOwner {
        require(_mintAmount > 0, "Need to mint at least 1 NFT");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "Max NFT limit exceeded");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(destination, supply + i);
            emit NFTiffMinted(destination, supply + i);
        }
    }

    //MINT Public
    function mintPublic(uint256 _mintAmount) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(publicSaleActive, "Sale has not started yet");
        require(msg.value >= cost * _mintAmount, "Insufficient funds");
        require(_mintAmount > 0, "Need to mint at least 1 NFT");
        require(_mintAmount <= maxMintAmount,"Max mint amount per transaction exceeded");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "Max NFT limit exceeded");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
            emit NFTiffMinted(msg.sender, supply + i);
        }
    }

    //CLAIM
    function claim(uint256 punk_, uint256 nftiff_, bytes memory _signature) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(nftiffClaims[nftiff_] == 0, "Already claimed nftiff");
        require(punkClaims[punk_] == 0, "Already claimed punk");
        require(ownerOf(nftiff_) == msg.sender, "Not nftiff owner");
        require(ICryptoPunks(punksContract).punkIndexToAddress(punk_) == msg.sender, "Not punks owner");

        bytes32 hash = keccak256(abi.encodePacked("shipping-verified", punk_, nftiff_, msg.sender));
        address signer_ = hash.toEthSignedMessageHash().recover(_signature);
        require(signer_ == signer, "Shipping not verified");

        totalClaimed++;
        nftiffClaims[nftiff_] = totalClaimed;
        punkClaims[punk_] = totalClaimed;

        claimInfo[totalClaimed] = ClaimInfo({
            punkId: punk_,
            nftiffId: nftiff_,
            timestamp: block.timestamp,
            claimer: msg.sender
        });
        emit Claimed(totalClaimed, msg.sender, punk_, nftiff_, block.timestamp);
    }

    //PUBLIC VIEWS

    function getSigner() public view returns (address) {
        return signer;
    }

    function isWhitelisted(address _user) public view returns (bool) {
        return whitelistedAddresses[_user];
    }

    function isBlacklisted(address _user) public view returns (bool) {
        return blacklistedAddresses[_user];
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory _tokenURI; 
        if (!revealed) {
            _tokenURI = notRevealedUri;
        } else {
            _tokenURI = _tokenURIs[tokenId];
        }

        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    //ONLY OWNER SETTERS
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public onlyOwner {
        require(_exists(tokenId), "URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
        emit TokenURIUpdated(tokenId, _tokenURI);
    }

    function reveal() public onlyOwner {
        revealed = true;
        emit Revealed();
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
        emit Paused(_state);
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
        emit CostChanged(_newCost);
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
        emit MaxMintAmountChanged(_newmaxMintAmount);
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
        emit NotRevealedUriChanged(_notRevealedURI);
    }

    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
        emit MaxSupplyChanged(_maxSupply);
    }

    function setPresaleStatus(bool _saleActive) public onlyOwner {
        presaleActive = _saleActive;
        emit PresaleStatusChanged(_saleActive);
    }

    function setPublicSaleStatus(bool _saleActive) public onlyOwner {
        publicSaleActive = _saleActive;
        emit PublicSaleStatusChanged(_saleActive);
    }

    function setKycRequired(bool _required) public onlyOwner {
        isKycRequired = _required;
        emit KycRequireChanged(_required);
    }

    function setSigner(address signer_) public onlyOwner {
        signer = signer_;
        emit SignerChanged(signer_);
    }

    function whitelistUsers(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelistedAddresses[addresses[i]] = true;
        }
        emit UsersWhitelisted(addresses);
    }

    function blacklistUsers(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklistedAddresses[addresses[i]] = true;
        }
        emit UsersBlacklisted(addresses);
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

}