 AirbitzCore (ABC) is a client-side blockchain and Edge Security SDK providing auto-encrypted
 and auto-backed up accounts and wallets with zero-knowledge security and privacy. 
 All blockchain/bitcoin private and public keys are fully encrypted by the users' credentials
 before being backed up on to peer to peer servers. ABC allows developers to create new
 Airbitz wallet accounts or login to pre-existing accounts. Account encrypted data is
 automatically synchronized between all devices and apps using the Airbitz SDK. This allows a
 third party application to generate payment requests or send funds for the users' account
 that may have been created on the Airbitz Mobile Bitcoin Wallet or any other Airbitz SDK
 application. 
 
 In addition, the ABCDataStore object in the Airbitz ABCAccount object allows developers to
 store arbitrary Edge-Secured data on the user's account which is automatically encrypted,
 automatically backed up, and automatically synchronized between the user's authenticated 
 devices.

 To get started, you'll first need an API key. Get one at http://developer.airbitz.co

 Next create an xcode project and install CocoaPods in the project. Include ABC by adding
 the following line to your 'Podfile'.

 ```pod 'AirbitzCore', :http => "https://developer.airbitz.co/download/airbitz-core-objc-newest.tgz"```

    // Global account object
    ABCAccount *gAccount;

    - (void) exampleMethod
    {
        // Create an account
        AirbitzCore *abc  = [[AirbitzCore alloc] init:@"YourAPIKeyHere"];
        gAccount = [abc createAccount:@"myusername" password:@"MyPa55w0rd!&" pin:@"4283" delegate:self error:nil];
        // New account is auto logged in after creation

        // Use Airbitz Edge Security to write encrypted/backed up/synchronized data to the account
        [gAccount.dataStore dataWrite:@"myAppUserInfo" withKey:@"user_email" withValue:@"theuser@hisdomain.com"];

        // Read back the data
        NSMutableString *usersEmail = [[NSMutableString alloc] init];
        [gAccount.dataStore dataRead:@"myAppUserInfo" withKey:@"user_email" data:usersEmail];

        // usersEmail now contains "theuser@hisdomain.com"

        // Create a wallet in the user account
        ABCWallet *wallet = [abcAccount createWallet:@"My Awesome Wallet" currency:nil];

        // Logout
        [abc logout:gAccount];

        // Log back in with full credentials
        gAccount = [abc passwordLogin:@"myusername" password:@"MyPa55w0rd!&" delegate:self error:nil];

        // Logout
        [abc logout:gAccount];

        // Log back in with PIN using completion handler codeblock
        [abc pinLogin:@"myusername" pin:@"4283" delegate:self complete:^(ABCAccount *account)
        {
            gAccount = account;

        } error:^(NSError *error) {
            NSLog(@"Argh! Error code: %d. Error string:%@", (int)error.code, error.userInfo[NSLocalizedDescriptionKey]);
        }];

    }

    // Delegate method called when wallets are loaded after a login
    - (void) abcAccountWalletLoaded:(ABCWallet *)wallet
    {
        // Create a bitcoin request
        ABCReceiveAddress *request = [wallet createNewReceiveAddress];

        // Put in some optional meta data into this request so incoming funds are automatically tagged
        request.metaData.payeeName     = @"William Swanson"; // Name of the person receiving request
        request.metaData.category      = @"Income:Rent";     // Category of payment. Auto tags category when funds come in
        request.metaData.notes         = @"Rent payment for Jan 2016";

        // Put in an optional request amount and use fiat exchange rate conversion methods
        request.amountSatoshi          = [gAccount.exchangeCache currencyToSatoshi:5.00 currencyCode:@"USD" error:nil];

        // Use the request results
        NSString *bitcoinAddress = request.address;
        NSString *bitcoinURI     = request.uri;
        UIImage  *bitcoinQRCode  = request.qrCode;

        // Now go and display the QR code or send payment to address in some other way.
    }

    // Delegate method called when bitcoin is received
    - (void) abcAccountIncomingBitcoin:(ABCWallet *)wallet txid:(NSString *)txid;
    {
        NSLog(@"Yay, my wallet just received bitcoin");
    }

