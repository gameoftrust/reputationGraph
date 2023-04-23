// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

/**
 * @title Nickname
 * @dev This contract allows users to set unique nicknames for their Ethereum addresses.
 * Users can either set their nicknames directly or use signed typed data to set them.
 */
contract Nickname {
    // State variables
    bytes32 public constant DOMAIN_SEPARATOR = keccak256(
        abi.encode(
            keccak256("EIP712Domain(string name,string version)"),
            keccak256(bytes("Game of Trust Nickname")),
            keccak256(bytes("1"))
        )
    );
    bytes32 public constant SET_NICKNAME_TYPE_HASH = keccak256("NicknameObject(address account,string nickname,uint256 timestamp)");
    mapping(address => string) public addressNicknames;
    mapping(string => bool) private _usedNicknames;
    mapping(address => uint256) public lastUsedTimestamps;
    
    struct NicknameObject {
        address account;
        string nickname;
        uint256 timestamp;
    }
    NicknameObject[] public nicknameObjects;

    // Custom errors
    error InvalidSignatureError();
    error NicknameAlreadyTakenError();
    error NotWalletOwnerError();
    error TimestampMustBeGreaterThanTheLastUsedTimestamp();

    // Events
    event NicknameChanged(address indexed account, string nickname);

    /**
     * @dev Modifier to require that the caller is the owner of the wallet address.
     */
    modifier onlyWalletOwner(address account) {
        if (msg.sender != account) {
            revert NotWalletOwnerError();
        }
        _;
    }

    /**
     * @dev Get the nickname of a wallet address.
     * @param account The address of the wallet.
     * @return The nickname associated with the wallet address.
     */
    function getNickname(address account) public view returns (string memory) {
        return addressNicknames[account];
    }

    /**
     * @notice Returns the length of the nicknameObjects array.
     * @return The length of the nicknameObjects array.
     */
    function getNicknamesArrayLength() external view returns (uint256) {
        return nicknameObjects.length;
    }

    /**
     * @notice Gets a slice of the nicknameObjects array.
     * @param fromIndex The start index of the slice (inclusive).
     * @param toIndex The end index of the slice (inclusive).
     * @return The sliced list of nicknameObjects.
     */
    function getNicknamesArray(uint256 fromIndex, uint256 toIndex) external view returns (NicknameObject[] memory) {
        NicknameObject[] memory slicedNicknameObjects = new NicknameObject[](toIndex - fromIndex + 1);
        for (uint256 i = fromIndex; i <= toIndex; i++) {
            slicedNicknameObjects[i - fromIndex] = (nicknameObjects[i]);
        }
        return slicedNicknameObjects;
    }

    /**
     * @dev Set the nickname of a wallet address. Can only be called by the wallet owner.
     * @param account The address of the wallet.
     * @param nickname The new nickname to be associated with the wallet address.
     */
    function setNickname(address account, string memory nickname) public onlyWalletOwner(account) {
        _setNickname(NicknameObject(account, nickname, block.timestamp));
    }

    /**
     * @dev Set the nickname of a wallet address using a signed typed data.
     * @param nicknameObject The NicknameObject containing the address, nickname, and timestamp.
     * @param signature The signature to validate the typed data.
     */
    function setNicknameWithSignedData(
        NicknameObject memory nicknameObject,
        bytes memory signature
    ) public {
        if (lastUsedTimestamps[nicknameObject.account] > nicknameObject.timestamp) {
            revert TimestampMustBeGreaterThanTheLastUsedTimestamp();
        }

        address signer = _getSigner(nicknameObject, signature);

        if (signer != nicknameObject.account) {
            revert InvalidSignatureError();
        }

        _setNickname(nicknameObject);
    }

    /**
     * @notice Given a hex signature, extracts its r, s, and v components.
     * @param sig The bytes of the signature.
     * @return r The components of the signature.
     * @return s The components of the signature.
     * @return v The components of the signature.
     */
    function _splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /**
     * @notice Recovers the signer of the NicknameObject from its signature according to the EIP-712 standard.
     * @param nicknameObject The NicknameObject.
     * @param sig The signature.
     * @return signer The address of the signer.
     */
    function _getSigner(NicknameObject memory nicknameObject, bytes memory sig) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(sig);

        bytes32 typeHash = keccak256(
            abi.encode(
                SET_NICKNAME_TYPE_HASH,
                nicknameObject.account,
                keccak256(bytes(nicknameObject.nickname)),
                nicknameObject.timestamp
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                typeHash
            )
        );
        return ecrecover(digest, v, r, s);
    }

    /**
     * @dev Internal function to set the nickname of a wallet address.
     * It also manages the used nicknames and emits the NicknameChanged event.
     * @param nicknameObject The NicknameObject containing the address, nickname, and timestamp.
     */
    function _setNickname(NicknameObject memory nicknameObject) internal {
        if (_usedNicknames[nicknameObject.nickname]) {
            revert NicknameAlreadyTakenError();
        }

        string memory currentNickname = addressNicknames[nicknameObject.account];
        if (bytes(currentNickname).length > 0) {
            _usedNicknames[currentNickname] = false;
        }

        addressNicknames[nicknameObject.account] = nicknameObject.nickname;
        _usedNicknames[nicknameObject.nickname] = true;
        lastUsedTimestamps[nicknameObject.account] = nicknameObject.timestamp;
        nicknameObjects.push(nicknameObject);
        emit NicknameChanged(nicknameObject.account, nicknameObject.nickname);
    }
}
