// SPDX-License-Identifier: Unlicense

// @title: NFTiff
// @author: Tiffany Team

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "hardhat/console.sol";

interface ICryptoPunks {
    function punkIndexToAddress(uint256) external view returns (address);
}

contract NFTiff is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using ECDSA for bytes32;

    string public notRevealedUri;
    mapping(uint256 => string) _tokenURIs;

    uint256 public cost = 30 ether;
    uint256 public maxSupply = 500;
    uint256 public maxMintAmount = 2;
    bool public presaleActive = false;
    bool public publicSaleActive = false;
    bool public paused = false;
    bool public revealed = false;
    bool public isKycRequired = true;
    address public signer; // signer to make signature
    mapping(address => bool) whitelistedAddresses;
    mapping(address => bool) blacklistedAddresses;
    address public immutable punksContract; // mainnet punks - 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB

    uint256 public totalClaimed;
    mapping(uint256 => ClaimInfo) public claimInfo; // claimId => ClaimInfo
    mapping(uint256 => bool) public nftiffClaimed;
    mapping(uint256 => bool) public punkClaimed;

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

    /** METHODS */
    constructor(string memory _initNotRevealedUri, address punksContract_) ERC721("NFTiff", "NFTiff") {
        setNotRevealedURI(_initNotRevealedUri);
        signer = msg.sender;
        punksContract = punksContract_;
    }
    
    //MODIFIERS
    modifier notPaused {
         require(!paused, "the contract is paused");
         _;
    }

    modifier notBlacklisted(address user_) {
         require(!blacklistedAddresses[user_], "user in blacklist");
         _;
    }

    // INTERNAL

    function presaleValidations(bytes memory _signature) internal view {
        require(isWhitelisted(msg.sender), "user is not whitelisted");

        if(isKycRequired) {
            bytes32 hash = keccak256(abi.encodePacked("kyc-approved", msg.sender));
            address signer_ = hash.toEthSignedMessageHash().recover(_signature);
            require(signer_ == signer, "Kyc not approved");
        }
    }

    //MINT
    function mint1(uint256 _mintAmount, bytes memory _signature) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(presaleActive, "Sale has not started yet");
        require(msg.value >= cost * _mintAmount, "insufficient funds");
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(_mintAmount <= maxMintAmount,"max mint amount per transaction exceeded");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        presaleValidations(_signature);

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
            emit NFTiffMinted(msg.sender, supply + i);
        }
    }
    
    function gift(uint256 _mintAmount, address destination) public onlyOwner {
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(destination, supply + i);
            emit NFTiffMinted(destination, supply + i);
        }
    }

    //MINT Public
    function mintPublic(uint256 _mintAmount) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(publicSaleActive, "Sale has not started yet");
        require(msg.value >= cost * _mintAmount, "insufficient funds");
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(_mintAmount <= maxMintAmount,"max mint amount per transaction exceeded");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
            emit NFTiffMinted(msg.sender, supply + i);
        }
    }

    //CLAIM
    function claim(uint256 punk_, uint256 nftiff_, bytes memory _signature) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(nftiffClaimed[nftiff_] == false, "already claimed nftiff");
        require(punkClaimed[punk_] == false, "already claimed punk");
        require(ownerOf(nftiff_) == msg.sender, "not nftiff owner");
        require(ICryptoPunks(punksContract).punkIndexToAddress(punk_) == msg.sender, "not punks owner");

        bytes32 hash = keccak256(abi.encodePacked("shipping-verified", punk_, nftiff_, msg.sender));
        address signer_ = hash.toEthSignedMessageHash().recover(_signature);
        require(signer_ == signer, "Shipping not verified");

        nftiffClaimed[nftiff_] = true;
        punkClaimed[punk_] = true;

        totalClaimed++;
        claimInfo[totalClaimed] = ClaimInfo({
            punkId: punk_,
            nftiffId: nftiff_,
            timestamp: block.timestamp,
            claimer: msg.sender
        });
        emit Claimed(totalClaimed, msg.sender, punk_, nftiff_, block.timestamp);
    }

    //PUBLIC VIEWS
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

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (!revealed) {
            return notRevealedUri;
        } else {
            return _tokenURIs[tokenId];
            // string memory currentBaseURI = _baseURI();
            // return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI,tokenId.toString(), baseExtension)) : "";
        }
    }

    //ONLY OWNER VIEWS

    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function getSigner() public view onlyOwner returns (address) {
        return signer;
    }

    //ONLY OWNER SETTERS
    function reveal() public onlyOwner {
        revealed = true;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setTokenURI(uint256 tokenId, string memory _uri) public onlyOwner {
        _tokenURIs[tokenId] = _uri;
        emit TokenURIUpdated(tokenId, _uri);
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    function setPresaleStatus(bool _saleActive) public onlyOwner {
        presaleActive = _saleActive;
    }

    function setPublicSaleStatus(bool _saleActive) public onlyOwner {
        publicSaleActive = _saleActive;
    }

    function setKycRequired(bool _required) public onlyOwner {
        isKycRequired = _required;
    }

    function setSigner(address signer_) public onlyOwner {
        signer = signer_;
    }

    function whitelistUsers(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelistedAddresses[addresses[i]] = true;
        }
    }

    function blacklistUsers(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklistedAddresses[addresses[i]] = true;
        }
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
}