class LegalContent {
  static const String privacyPolicy = r"""
# SnapSweep Privacy Policy

Effective date: 6 November 2026

## Gallery processing and local storage
SnapSweep accesses only the photos and videos Android allows you to share with it. Duplicate detection, visual similarity checks, categorization, previews and compression run on your device. SnapSweep does not upload gallery files or recognized text to a developer server for analysis. It does not require a SnapSweep login or registration.

Local app storage contains media identifiers, folder information, file sizes, content hashes, category assignments, saved scan results, preferences and cached ad-free entitlement. Temporary previews and compressed output may be created in app cache. Saved compressed copies remain in your gallery. Clearing app data or uninstalling removes the app's local records; it does not remove gallery copies you saved. Android backup settings may retain or restore app data according to your device configuration.

## Advertising and consent
The free version may display a clearly marked native ad on the dashboard and an interstitial at a completed-task transition after you choose Continue. Completing a task does not require an ad to load, and the app does not reward ad clicks. Ad-free purchasers are excluded from these placements.

Google Mobile Ads and its advertising partners may collect or share IP addresses, approximate location inferred from IP, advertising/device or account identifiers, app and ad interactions, and diagnostic information for advertising, measurement, analytics and fraud prevention. Advertising choices and applicable consent determine how ads are requested; they do not mean all advertising-related network data collection stops. Where required, Google's User Messaging Platform presents consent choices. An Advertising privacy choices entry is available in Settings when required by that platform. Android's advertising settings provide additional controls.

Google's disclosures: https://developers.google.com/admob/android/privacy/play-data-disclosure
Google privacy policy: https://policies.google.com/privacy

## Machine learning services
The app uses Google's on-device ML Kit for image labeling, text recognition and, in supported processing paths, face detection. Face detection is used for image organization, not to identify named people. ML Kit processes input images and recognized content on-device; its SDK may send technical, device and API usage/diagnostic information to Google under its terms. Gallery images and classification output are not sent by SnapSweep for cloud analysis.

ML Kit terms and privacy: https://developers.google.com/ml-kit/terms

## Purchases
Google Play handles the one-time Remove Ads purchase and payment details. SnapSweep receives product information, purchase status and purchase tokens to manage entitlement and restoration. SnapSweep does not receive your payment card details. Restore Purchases checks ownership through Google Play; a connection and the purchasing Google Play account may be required. Google controls its own account, payment, retention and refund records.

## Internet access
Free-user access requires an internet connection. The app periodically contacts a Google-hosted connectivity endpoint without gallery content. Like other network requests, this reveals connection information such as your IP address to that provider. Ad-free purchasers are exempt from the advertising connectivity gate. SnapSweep checks Google Play for updates at startup, on returning to the app and periodically while using it. A confirmed newer version must be installed before continuing, including for ad-free purchasers. An unavailable update check does not itself block access. A previously confirmed newer version can remain required until installed or Google Play confirms it is no longer available. These checks share app/version and connection information with Google Play, not gallery content. A working connection does not guarantee an advertisement will be available.

## Your controls and retention
You can limit or revoke gallery permissions in Android Settings, change required advertising consent through the app's privacy choices, clear app data, or uninstall. Local analysis data stays until refreshed, removed, cleared or uninstalled. Google and advertising partners retain service data under their own policies; clearing SnapSweep's data does not delete their records. Do not send sensitive gallery images when requesting support unless you choose to do so.

## Changes and contact
Material changes will be reflected in an updated effective date and the app's policy. For privacy questions or applicable data-rights requests, contact the developer using the support contact shown on SnapSweep's Google Play listing. This policy does not restrict rights available under applicable law.
""";

  static const String termsOfService = r"""
# SnapSweep Terms and Conditions

Effective date: 6 November 2026

## Using the app
These terms govern your use of SnapSweep. Use the app only for media you are authorized to manage and in accordance with applicable laws, age restrictions and the Google Play terms. You do not need a SnapSweep account. You receive a personal license to use the app; these terms do not transfer ownership of your media to the developer.

## Review before cleanup
Exact duplicate results are based on byte-content checks performed during analysis. Similar images, burst keepers, blur assessments and category assignments are automated suggestions and may be incorrect. Cached results describe a previous scan; refresh after gallery changes. Review every selected item and keep backups before deletion, replacement or compression. The app does not provide cloud backup or guarantee recovery.

Android 11 and later may support moving media to Trash. Recovery, retention and when storage is actually reclaimed depend on the device and gallery settings. On older or unsupported systems, deletion can be permanent. Compression can change quality and metadata. Original replacement is attempted only after a compressed copy has been saved, but you should verify the saved copy before removing valuable originals.

## Free access and advertising
The free version is advertising-supported and requires internet access. It may show a dashboard native ad and a completion interstitial after Continue. Ads are subject to availability, consent and frequency controls; core cleanup operations are not conditional on ad playback or clicks. Third-party ads and external destinations are operated by their providers. The app's Privacy Policy explains their data practices and available choices.

## Remove Ads purchase
The purchase screen shows the current Google Play price and applicable charges before you confirm. Remove Ads is a one-time purchase, not a subscription, for the advertised ad-free entitlement in this Android app. It does not promise unspecified future paid services or benefits on other platforms. Google Play processes payment. Restoration depends on store ownership and normally requires the same purchasing Google Play account and a network connection. Uninstalling does not itself refund a purchase. Refund requests and entitlement changes follow Google Play's policies and applicable consumer law: https://support.google.com/googleplay/answer/2479637

## Availability and responsibility
Features depend on Android permissions, device resources, supported media formats and service availability. Processing time and storage savings vary, and no classification accuracy, scan duration or compression ratio is guaranteed. Do not misuse the app or interfere with other users or services.

To the extent permitted by law, the app is supplied without additional promises of uninterrupted or error-free operation. Liability is limited only where applicable law allows. Nothing in these terms excludes mandatory consumer rights or liability that cannot legally be excluded. These terms do not override Google Play's applicable terms.

## Updates, privacy and contact
Google Play updates are required for continued app access, including for ad-free purchasers. The app blocks access when Google Play confirms an available version newer than the installed version. An unavailable check does not itself block access. A previously confirmed newer version can remain required until installed or Google Play confirms it is no longer available. An internet connection and Google Play support are needed to check and install updates. Buying Remove Ads does not bypass these requirements.

The app may receive changes and fixes; material changes to these terms will be published with an updated effective date. Continued use is subject to the updated terms to the extent permitted by law. The Privacy Policy forms part of the information provided about the service. For support, purchase or legal questions, contact the developer using the support contact on SnapSweep's Google Play listing.
""";
}
