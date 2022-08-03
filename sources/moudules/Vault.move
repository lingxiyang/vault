module Vault::Vault{
  
    use std::signer;
    use std::debug;
     use std::error;
    // use std
     
    const EVAULT_INFO_ALREADY_PUBLISHED: u64 = 1; 
    const EVAULT_INFO_ALREADY_EXISTS :u64 = 2;
    const EVAULT_INFO_NO_EXISTS:u64 = 3;
    const EVAULT_INFO_PAUSE :u64 = 4;
    const EINSUFFICIENT_BALANCE: u64 = 5;
    const EVAULT_INFO_MISMATCH: u64 = 6;

    const ENO_CAPABILITIES:u64=7;

    const VAULT_STATUS_PAUSE :u8= 1;
    const VAULT_STATUS_UNPAUSE:u8 = 0;
    struct ManagedCoin has store{
      value:u64
    }
    struct Vault has key{
      coin:ManagedCoin,
      root:address
    }   
    struct VaultManager has key{
       manager:address,
       status:u8
    }
    struct PauseCapability has key, store {}
    public fun initialize(creator:&signer){
          let account_addr = signer::address_of(creator);
          assert!(!exists<VaultManager>(account_addr),EVAULT_INFO_ALREADY_PUBLISHED);
          let manage = VaultManager{
            manager:account_addr,
            status:VAULT_STATUS_UNPAUSE
          };
          move_to(creator,manage);
          move_to(creator,PauseCapability{});
    }
   public fun register_vault(creator:&signer,init_coin:u64) :bool acquires VaultManager{
        let account_addr = signer::address_of(creator);
        assert!(!exists<Vault>(account_addr),EVAULT_INFO_ALREADY_EXISTS);
        let vaultManage = borrow_global<VaultManager>(@manage);
        debug::print(&account_addr);
        if(vaultManage.status == VAULT_STATUS_UNPAUSE){
            let vault = Vault{
                coin :ManagedCoin{
                  value:init_coin
                },
                root:vaultManage.manager  
            };
            move_to(creator,vault);
            true
        }else{
          false
        }
   }
   
   public fun deposit(from:&signer,coin:ManagedCoin) acquires Vault ,VaultManager{
      let account_addr = signer::address_of(from);
      // let vault_addr = signer::address_of(@Vault);
      let vaultManage = borrow_global<VaultManager>(@manage);
      assert!(vaultManage.status == VAULT_STATUS_UNPAUSE,EVAULT_INFO_PAUSE);
      assert!(exists<Vault>(account_addr),EVAULT_INFO_NO_EXISTS);
      let coins = &mut borrow_global_mut<Vault>(account_addr).coin;
      coins.value = coins.value + coin.value;
      let ManagedCoin{value:_} = coin;
   }
   public fun withdraws(from:&signer,amount:u64): ManagedCoin acquires VaultManager,Vault{
      let account_addr = signer::address_of(from);
      // let vault_addr = signer::address_of(@Vault);
      let vaultManage = borrow_global<VaultManager>(@manage);
      assert!(vaultManage.status == VAULT_STATUS_UNPAUSE,EVAULT_INFO_PAUSE);
      assert!(exists<Vault>(account_addr),EVAULT_INFO_NO_EXISTS);
       let vault = borrow_global_mut<Vault>(account_addr);
       extract(&mut vault.coin,amount)
   }
   public fun extract(coin: &mut ManagedCoin, amount: u64): ManagedCoin {
        assert!(coin.value >= amount, error::invalid_argument(EINSUFFICIENT_BALANCE));
        coin.value = coin.value - amount;
        ManagedCoin { value: amount }
    }

    public fun get_balance(from: &signer):u64 acquires Vault{
      let account_addr = signer::address_of(from);
       let vault = borrow_global<Vault>(account_addr);
       vault.coin.value
    }

    public fun pause(manager: &signer) acquires VaultManager{
       let account_addr = signer::address_of(manager);
       assert!(exists<VaultManager>(account_addr),EVAULT_INFO_NO_EXISTS);
      //  assert!(manager==@manage,EVAULT_INFO_MISMATCH)
       assert!(
            exists<PauseCapability>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );
      let vaultManage = borrow_global_mut<VaultManager>(@manage);
      vaultManage.status = VAULT_STATUS_PAUSE;
    }
    public fun resume(manager: &signer) acquires VaultManager{
       let account_addr = signer::address_of(manager);
       assert!(
            exists<PauseCapability>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );
       assert!(exists<VaultManager>(account_addr),EVAULT_INFO_NO_EXISTS);
      //  assert!(manager==@manage,EVAULT_INFO_MISMATCH)
      let vaultManage = borrow_global_mut<VaultManager>(account_addr);
      vaultManage.status = VAULT_STATUS_UNPAUSE;
    }

     #[test(source = @0x10, destination = @0x6)]
    public entry fun end_to_end(
        source: signer,
        destination:signer
    ) acquires VaultManager,Vault{
        initialize(&source);
        register_vault(&destination,1000);
        register_vault(&source,1000);
        let coin = withdraws(&destination,100);
        deposit(&source,coin);
        let dest_balance = get_balance(&destination);
        let source_balance = get_balance(&source);
        assert!(dest_balance==900,1);
        assert!(source_balance==1100,1);
    }
 #[test(source = @0x10, destination = @0x6)]
    public entry fun pause_vault(
        source: signer,
        destination:signer
    ) acquires VaultManager,Vault{
       
        initialize(&source);
        register_vault(&destination,1000);
         register_vault(&source,1000);
        let coin1 = withdraws(&destination,100);
        deposit(&source,coin1);
        pause(&source);
        let coin2= withdraws(&destination,100);
        deposit(&source,coin2);
    }
    #[test(source = @0x10, destination = @0x6)]
    public entry fun resume_vault(
        source: signer,
        destination:signer
    ) acquires VaultManager,Vault{
       
        initialize(&source);
        register_vault(&destination,1000);
         register_vault(&source,1000);
        // let coin1 = withdraws(&destination,100);
        // deposit(&source,coin1);
        pause(&source);
        resume(&source);
        let coin2= withdraws(&destination,100);
        deposit(&source,coin2);
        let dest_balance = get_balance(&destination);
        let source_balance = get_balance(&source);
        assert!(dest_balance==900,1);
        assert!(source_balance==1100,1);
    }
}