module coin_swap::verra {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{Self};
    use sui::table::{Table, Self};
    use sui::dynamic_field as df;
    use std::string::{Self, String};

    const ENotTheSameCurrency: u64 = 0;

    const ENotEnoughBalance: u64 = 1;

    const ESelfTransfer: u64 = 2;

    const EMinusTransferAmount: u64 = 3;

    const ENotIndendedReceiver: u64 = 4;

    struct CreateTransferEvent has copy, drop {
        from: address,
        to: address,
        description: String,
        amount: u16,
        currency: String
    }

    struct AcceptTransferEvent has copy, drop {
        from: address,
        to: address,
        description: String,
        amount: u16,
        currency: String
    }

    struct CoinAdminCap has key {
        id: UID,
        description: String
    }

    struct Pocket has key {
        id: UID,
        currency: String,
        type: String,
        balance: u16,
        owner: address
    }

    struct UserCap has key {
        id: UID,
        description: String
    }

    struct UserInfo has key {
        id: UID,
        // CreatedTime, user address, etc
        user_address: address,
        profile_pic_url: String,
        type: String
    }

    struct Transfer has key {
        id: UID,
        from: address,
        to: address,
        description: String,
        amount: u16,
        currency: String
    }

    struct ExchangeRatePublisher has key {
        id: UID,
        fee: u64,
        description: String,
        source_url: String
    }

    fun init(ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        transfer::transfer(CoinAdminCap {
            id: object::new(ctx),
            description: string::utf8(b"Admin level capability")
        }, admin_address);

        create_user(admin_address, string::utf8(b"random profile pic"), admin_type(), ctx);

        // Creates a new rate publisher
        let exchange_rate_publisher = ExchangeRatePublisher {
            id: object::new(ctx),
            fee: 50,
            description: string::utf8(b"A new exchange rate publisher"),
            source_url: string::utf8(b"A source url to forex price exchange")
        };
        let rates = table::new<String, u64>(ctx);
        df::add(&mut exchange_rate_publisher.id, publisher_rates(), rates);
        let fees = table::new<String, u64>(ctx);
        df::add(&mut exchange_rate_publisher.id, publisher_fees(), fees);
        let pockets = table::new<String, Pocket>(ctx);
        df::add(&mut exchange_rate_publisher.id, publisher_pockets(), pockets);

        transfer::share_object(exchange_rate_publisher);
    }

    /// Signs up a user when user requests it. For simplicity, we auto-verify the user and create
    /// user cap and transfer it to the user.
    public entry fun create_user(user_address: address,
                                profile_pic_url: String,
                                type: String,
                                ctx: &mut TxContext) {
        let description = if (type == individual_type()) {
            string::utf8(b"User leve capability")
        } else if (type == admin_type()) {
            string::utf8(b"Admin leve capability")
        } else {
            string::utf8(b"Error")
        };
        transfer::transfer(UserCap {
            id: object::new(ctx),
            description
        }, user_address);
        transfer::transfer(UserInfo {
            id: object::new(ctx),
            user_address,
            profile_pic_url,
            type
        }, user_address);

        create_pockets(user_address, type, ctx);
    }

    /// Creates corresponding pockets for each new user
    fun create_pockets(user_address: address, type: String, ctx: &mut TxContext) {
        // Initialize empty pockets with different currencies for admin
        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"USD"),
            type,
            balance: 0,
            owner: tx_context::sender(ctx)
        }, user_address);

        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"EUR"),
            type,
            balance: 0,
            owner: tx_context::sender(ctx)
        }, user_address);

        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"PLN"),
            type,
            balance: 0,
            owner: tx_context::sender(ctx)
        }, user_address);
    }

    fun individual_type(): (String) { string::utf8(b"individual") }
    fun admin_type(): (String) { string::utf8(b"admin") }
    fun publisher_rates(): (String) { string::utf8(b"rates") }
    fun publisher_fees(): (String) { string::utf8(b"fees") }
    fun publisher_pockets(): (String) { string::utf8(b"pockets") }

    public entry fun create_transfer(_: &UserCap,
                                    from_pocket: &mut Pocket,
                                    to: address,
                                    description: String,
                                    amount: u16,
                                    currency: String,
                                    ctx: &mut TxContext) {
        let from = tx_context::sender(ctx);
        assert!(amount > 0, EMinusTransferAmount);
        assert!(from_pocket.balance - amount >= 0, ENotEnoughBalance);
        assert!(from != to, ESelfTransfer);
        from_pocket.balance = from_pocket.balance - amount;
        transfer::transfer(Transfer {
            id: object::new(ctx),
            from,
            to,
            description,
            amount,
            currency
        }, to);
        event::emit(CreateTransferEvent {
            from,
            to,
            description,
            amount,
            currency
        });
    }

    public entry fun accept_transfer(_: &UserCap, pocket: &mut Pocket, transfer: Transfer) {
        let Transfer {
            id,
            from,
            to,
            description,
            amount,
            currency
        } = transfer;
        assert!(from != pocket.owner, ESelfTransfer);
        assert!(pocket.currency == currency, EMinusTransferAmount);
        assert!(to == pocket.owner, ENotIndendedReceiver);

        pocket.balance = pocket.balance + amount;
        object::delete(id);

        event::emit(AcceptTransferEvent {
            from,
            to,
            description,
            amount,
            currency
        });
    }

    /// Method for only coinadmin
    fun create_admin_transfer_(_: &CoinAdminCap,
                            from_pocket: &mut Pocket,
                            to: address,
                            description: String,
                            amount: u16,
                            currency: String,
                            ctx: &mut TxContext) {
        let from = tx_context::sender(ctx);
        assert!(amount > 0, EMinusTransferAmount);
        assert!(from_pocket.balance - amount >= 0, ENotEnoughBalance);
        assert!(from != to, ESelfTransfer);
        from_pocket.balance = from_pocket.balance - amount;
        transfer::transfer(Transfer {
            id: object::new(ctx),
            from,
            to,
            description,
            amount,
            currency
        }, to);
        event::emit(CreateTransferEvent {
            from,
            to,
            description,
            amount,
            currency
        });
    }

    // It's equal as in minting, since we are creating balance out of nowhere for admin.
    // Or we deduct same amount from admin's pocket
    fun topup_exchange(admin_cap: &CoinAdminCap, publisher: &mut ExchangeRatePublisher) {

    }

    fun collect_fees() {
        
    }

    /// Mints new balance with requested currency for admin pocket
    public entry fun mint(admin_cap: &CoinAdminCap,
                        pocket: &mut Pocket,
                        to: address,
                        amount: u16,
                        currency: String,
                        ctx: &mut TxContext) {
        // Should check whether requested currency matches the symbol of the pocket
        assert!(pocket.currency == currency, ENotTheSameCurrency);
        assert!(to != pocket.owner, ESelfTransfer);
        pocket.balance = pocket.balance + amount;
        let description = string::utf8(b"Admin topup");
        // Then a new transfer should be created to be sent to the destination
        create_admin_transfer_(admin_cap, pocket, to, description, amount, currency, ctx);
    }

    // /// Destroys balance with requested currency
    // TODO: Or will be implemented in the end
    // public fun destroy(_: &CoinAdminCap, pocket: &mut Pocket, amount: u16, currency: String) {
    //     assert!(pocket.currency == currency, ENotTheSameCurrency);
    //     assert!(pocket.balance > amount, ENotEnoughBalance);
    //     pocket.balance = pocket.balance - amount;
    // }

    public fun update_fee(_: &CoinAdminCap, fee: u16, currency_pair: String) {
        
    }

    public fun add_currency_pair(_: &CoinAdminCap, rate: u16, currency_pair: String) {

    }

    public fun remove_currency_pair(_: &CoinAdminCap, currency_pair: String) {

    }

    public entry fun request_exchange(_: &UserCap,
                                    from: &mut Pocket,
                                    exchange_rate_publisher: &mut ExchangeRatePublisher,
                                    currency_pair: String,
                                    amount: u16) {
        // Checks whether currency_pair exists
        // Checks whether from Pocket has enough balance
        // Checks whether from Pocket has the same currency type
        // Calculates the fee by adding it to the cost
        // 
    }
    

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    public fun get_admin_cap(self: &CoinAdminCap): String {
        self.description
    }

    public fun get_pocket(self: &Pocket): (String, String, u16, address) {
        (self.currency, self.type, self.balance, self.owner)
    }

    public fun get_user_info(self: &UserInfo): (address, String, String) {
        (self.user_address, self.profile_pic_url, self.type)
    }

    public fun get_transfer(self: &Transfer): (address, address, String, u16, String) {
        (self.from, self.to, self.description, self.amount, self.currency)
    }

    public fun get_publisher(self: &ExchangeRatePublisher): (&Table<String, u64>, &Table<String, u64>) {
        let rates = df::borrow(&self.id, publisher_rates());
        let fees = df::borrow(&self.id, publisher_fees());
        (rates, fees)
    }
}
