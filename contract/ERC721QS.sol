// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./IERC721QS.sol";

abstract contract ERC721QS is ERC721Enumerable, IERC721QS {

    ///合约构建时，传入参数address和bool,如果是SBT，则bool="true"，初始化guard地址为“initializedGuardAddress”
    address initializedGuardAddress;
    bool isSBT;
    

    constructor(address initializedGuardAddress_,bool isSBT_,string memory name_, string memory symbol_) ERC721(name_, symbol_) {
    initializedGuardAddress= initializedGuardAddress_;
    isSBT=isSBT_;
    }
    
    mapping(uint256 => address) internal token_guard_map;

    /// @notice Update the guard of the NFT
    /// @dev Delete function: set guard  to 0 address,update function: set guard to new address
    /// Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to update the guard address for
    /// @param newGuard The newGuard address
    /// @param allowNull Allow 0 address
    function updateGuard(uint256 tokenId,address newGuard,bool allowNull) internal {
        address owner = ownerOf(tokenId); 
        address guard = guardOf(tokenId);
        if (!allowNull) {
            require(newGuard != address(0), "New guard can not be null");
        }
        if (guard != address(0)) { 
            require(guard == _msgSender(), "only guard can change it self"); 
        } else { 
            require(owner == _msgSender(), "only owner can set guard"); 
            ///若想支持授权者也可以设置guard，则采用下述require
            ///require(_isApprovedOrOwner(_msgSender(), tokenId),"ERC721QS: caller is not owner nor approved");
        } 

        if (guard != address(0) || newGuard != address(0)) {
            token_guard_map[tokenId] = newGuard;
            emit UpdateGuardLog(tokenId, newGuard, guard);
        }
    }

    /// @notice Owner sets guard or guard modifies guard
    /// @dev The newGuard can not be zero address
    /// Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to get the guard address for
    /// @param newGuard The new guard address of the NFT
    function changeGuard(uint256 tokenId, address newGuard) public virtual{
        updateGuard(tokenId, newGuard, false);
    }

    /// @notice Remove the guard of the NFT
    /// @dev The guard address is set to 0 address
    ///      Only guard can remove its own guard role
    /// Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to remove the guard address for
    function removeGuard(uint256 tokenId) public virtual  {
        updateGuard(tokenId, address(0), true);
    }
    
    /// @notice Transfer the NFT and remove its guard role
    /// Throws  if `tokenId` is not valid NFT
    /// @param  from The address of the previous owner of the NFT
    /// @param  to The address of NFT recipient 
    /// @param  tokenId The NFT to get transferred for
    function transferAndRemove(address from,address to,uint256 tokenId) public virtual {
        transferFrom(from,to,tokenId);
        removeGuard(tokenId);
    }
    
    /// @notice Get the guard address of the NFT
    /// @dev The zero address indicates that there is no guard
    /// Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to get the guard address for
    /// @return The guard address for the NFT
    function guardOf(uint256 tokenId) public view virtual returns (address) {
        return token_guard_map[tokenId];
    }
    
    
    /// @notice Check the guard address
    /// @dev The zero address indicates there is no guard
    /// Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to check the guard address for
    /// @return The guard address
    function checkOnlyGuard(uint256 tokenId) internal view returns (address) {
        address guard = guardOf(tokenId);
        address sender = _msgSender();
        if (guard != address(0)) {
            require(guard == sender, "sender is not guard of token");
            return guard;
        }else{
            return address(0);
        }
    }
 
    /// @dev Before transferring the NFT, need to check the gurard address
    function transferFrom(address from,address to,uint256 tokenId) public virtual override {
        address guard;
        address new_from = from;
        if (from != address(0)) {
            guard = checkOnlyGuard(tokenId);
            new_from = ownerOf(tokenId);
        }
        if (guard == address(0)) {
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        }
        _transfer(new_from, to, tokenId);
    }

    /// @dev Before transferring the NFT, need to check the gurard address
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes memory _data) public virtual override {
        address guard;
        address new_from = from;
        if (from != address(0)) {
            guard = checkOnlyGuard(tokenId);
            new_from = ownerOf(tokenId);
        }
        if (guard == address(0)) {
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        }
        _safeTransfer(from, to, tokenId, _data);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721QS).interfaceId || super.supportsInterface(interfaceId);
    }

    ///铸造方案1,区分是否是SBT，如果是SBT，铸造时则赋予guard，token_guard_map[tokenId]=initializedGuardAddress

    function _beforeTokenTransfer(address from,address to,uint256 tokenId,uint256 batchSize) internal virtual override{
        super._beforeTokenTransfer(from, to, tokenId,batchSize);
        if(from==address(0)&&isSBT){
            token_guard_map[tokenId]=initializedGuardAddress;
        }
    }

    ///销毁方案1 重写_afterTokenTransfer
    function _afterTokenTransfer(address from,address to,uint256 tokenId,uint256 batchSize) internal virtual override{
        super._afterTokenTransfer(from, to, tokenId,batchSize);
        if(to==address(0)){
            delete token_guard_map[tokenId]; 
        }
    }

    ///铸造方案2（使用super._mint，不确定能否行的通）

    function _mint(address to, uint256 tokenId) internal virtual override{
        if(isSBT){
            token_guard_map[tokenId]=initializedGuardAddress;
        }
        super._mint(to,tokenId);

    }

    ///销毁方案2，继承super._burn(tokenId)
        function _burn(uint256 tokenId) internal virtual override {
            super._burn(tokenId);
            delete token_guard_map[tokenId];
    }

    ///铸造方案3（重新定义一个函数_sbtmint，调用_mint）;

    function _sbtMint(address to, uint256 tokenId) internal virtual{
        if(isSBT){
            token_guard_map[tokenId]=initializedGuardAddress;
        }    
        _mint(to, tokenId);
    }

    ///销毁方案3 多写_safeBurn，调用_burn(tokenId)

    function _safeBurn(uint256 tokenId) internal virtual
    {
        delete token_guard_map[tokenId];
        _burn(tokenId);
    }
}

/*
销毁方案4：重写_burn，但由于ERC721中的指针可见性为private,直接重写会报错
------------------------------
    function _burn(uint256 tokenId) internal virtual override {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721.ownerOf(tokenId);
///-----ERC721中的_tokenApprovals[tokenId]，_balances[owner]，_owners[tokenId]，指针被定义为private了，执行会报错
        // Clear approvals
        delete _tokenApprovals[tokenId]; 

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];
        ///可选方法1-------删除guard
        delete token_guard_map[tokenId];

        ///可选方法2------校验guard，如果有guard，就删除不了

        require(guardOf(tokenId) == address(0));

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }


---------------------------------------
*/    
/*
///铸造方案4（重写_mint，但可能是由于ERRC721指针被定义为private，编译会报错。DeclarationError: Undeclared identifier.）
    function _mint(address to, uint256 tokenId) internal virtual override{
        if(isSBT){
            token_guard_map[tokenId]=initializedGuardAddress;
        }
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }
*/

    
