//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

contract OTCMarket is
    OwnableUpgradeable,
    IERC1155ReceiverUpgradeable,
    IERC721ReceiverUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct Offer {
        uint256 offerId;
        address nftAddress;
        address currency;
        address seller;
        uint256 tokenId;
        uint256 price;
    }

    bytes4 internal constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 internal constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    /// @notice address that can withdraw funds from contract.
    address public beneficiary;

    /// @notice fee that will be cut as a listing price. 100% = 10000
    uint64 public taxFee;

    /// @notice id of the last offer
    uint256 public lastOfferId;

    mapping(uint256 => Offer) public offers;

    ///
    /// events
    ///

    /// @notice emitted when offer is created
    event OfferCreated(
        uint256 offerId,
        address _nftAddress,
        address _currency,
        uint256 _tokenId,
        uint256 _price
    );

    /// @notice emitted when offer is accepted
    event OfferAccepted(
        uint256 offerId,
        address _nftAddress,
        address _currency,
        uint256 _tokenId,
        uint256 _price
    );

    /// @notice emitted when offer is cancelled
    event OfferCancelled(uint256 offerId);

    function initialize(uint64 _taxFee, address _beneficiary)
        external
        initializer
    {
        taxFee = _taxFee;
        beneficiary = _beneficiary;
        __Ownable_init();
    }

    /// @notice create new offer
    /// @return offerId the id of offer just created
    function createOffer(
        address _nftAddress,
        address _currency,
        uint256 _tokenId,
        uint256 _price
    ) external returns (uint256) {
        uint256 currentOfferId = lastOfferId;

        if (
            IERC165Upgradeable(_nftAddress).supportsInterface(
                INTERFACE_ID_ERC1155
            )
        ) {
            IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                1,
                "0x"
            );
        } else {
            IERC721Upgradeable(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId
            );
        }

        Offer memory offer;
        offer.offerId = currentOfferId;
        offer.nftAddress = _nftAddress;
        offer.currency = _currency;
        offer.seller = msg.sender;
        offer.tokenId = _tokenId;
        offer.price = _price;

        offers[currentOfferId] = offer;
        ++lastOfferId;

        emit OfferCreated(
            currentOfferId,
            _nftAddress,
            _currency,
            _tokenId,
            _price
        );
        return currentOfferId;
    }

    /// @notice accept the offer
    function acceptOffer(uint256 _offerId) external {
        require(_offerId < lastOfferId, "INVALID_OFFER_ID");

        Offer memory offer = offers[_offerId];

        uint256 taxPrice = (offer.price * taxFee) / 10000;
        IERC20Upgradeable(offer.currency).transferFrom(
            msg.sender,
            address(this),
            offer.price
        );
        IERC20Upgradeable(offer.currency).transfer(
            msg.sender,
            offer.price - taxPrice
        );

        if (
            IERC165Upgradeable(offer.nftAddress).supportsInterface(
                INTERFACE_ID_ERC1155
            )
        ) {
            IERC1155Upgradeable(offer.nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                offer.tokenId,
                1,
                "0x"
            );
        } else {
            IERC721Upgradeable(offer.nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                offer.tokenId
            );
        }
        emit OfferAccepted(
            _offerId,
            offer.nftAddress,
            offer.currency,
            offer.tokenId,
            offer.price
        );
        delete offers[_offerId];
    }

    /// @notice cancel the offer
    function cancelOffer(uint256 _offerId) external {
        require(_offerId < lastOfferId, "INVALID_OFFER_ID");
        Offer memory offer = offers[_offerId];
        require(offer.seller == msg.sender, "NOT_A_SELLER");

        delete offers[_offerId];

        emit OfferCancelled(_offerId);
    }

    /// @notice update the fee
    function setFee(uint64 _fee) external onlyOwner {
        taxFee = _fee;
    }

    /// @notice update the fee
    function setBeneficiary(address _beneficiary) external {
        require(beneficiary == msg.sender, "NOT_A_BENEFICIARY");
        beneficiary = _beneficiary;
    }

    /// @notice withdraw funds from contract
    function withdraw(address _currency) external {
        require(beneficiary == msg.sender, "NOT_A_BENEFICIARY");
        uint256 balance = IERC20Upgradeable(_currency).balanceOf(address(this));
        IERC20Upgradeable(_currency).transfer(beneficiary, balance);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
}
