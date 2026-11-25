# F&B Ordering: menu and cart

A slice of a consumer F&B ordering app: a menu grouped by category, a cart, and a simulated checkout. Flutter with Material 3, for Android (API 26+) and iOS (16+).

## Setup

Requires Flutter 3.38.10 or later (Dart 3.10.9), pinned in `.fvmrc`, and a device or simulator.

```bash
flutter pub get
flutter run
```

With fvm: `fvm install`, then `fvm flutter pub get` and `fvm flutter run`. Checks: `flutter analyze` and `flutter test`. No API key, account or environment variable is needed.

## Data source

**Menu:** [DummyJSON products](https://dummyjson.com/docs/products), one request. It returns 194 products in 24 categories; products stand in for menu items. The API sends no currency, so prices are shown as `RM` for display only.

```
GET https://dummyjson.com/products?limit=0&select=id,title,description,category,price,stock,availabilityStatus,thumbnail
```

**Checkout:** simulated in `SimulatedCheckoutRepository`. It waits 1.5 seconds and succeeds, unless the order total is over RM1,000, in which case it is rejected with a reason.

| To see | Do this |
|---|---|
| An order succeed | Keep the total at RM1,000 or less and place the order |
| An order rejected | Make the total over RM1,000, for example the bed under Furniture (RM1,899.99) |
| A sold-out item | Four items are sold out, for example "Sportbike Motorcycle" under Motorcycle |
| The menu fail to load | Turn off the network (for the iOS simulator, the Mac's), launch, turn it back on, tap "Try again" |
| Light and dark | The app follows the system theme. iOS simulator: Cmd+Shift+A. Android 10+: the dark theme quick-settings tile |

The checkout's network-failure path cannot be reached with the simulated checkout. `test/checkout_flow_test.dart` covers the failure and its "Try again" button; the retry itself is not tested.

## Architecture

```
lib/
  app.dart        creates repositories and Cubits, theme, the order-result snackbar
  models/         domain: plain Dart, no Flutter, no JSON
  repositories/   data: contracts, the HTTP client, the DummyJSON mapping, the simulated checkout
  cubits/         state: MenuCubit (sealed loading | loaded | failure), CartCubit (lines + sealed checkout status)
  screens/        UI: menu and cart screens, layout arithmetic for the tab row, widgets/
test/             8 Cubit tests and 7 widget tests
```

**Dependencies.** Imports point downward only (screens → cubits → repositories → models). Cubits depend on repository contracts; only `app.dart` names implementations and provides them above `MaterialApp`, so the cart survives navigation, rotation, a theme change and window resizing. No service locator, no global mutable state.

**Why Cubit and `Navigator.push`.** Two small state machines driven by method calls, and two screens with no deep links: Bloc events and a router would be ceremony.

**Promo codes.**

- **Add:** `PromoRepository` and a `PromoQuote` model; the server prices the discount.
- **Change:** `CartState` and `CartCubit` (code, promo status, `applyPromo`; any cart edit invalidates the quote and blocks ordering until it is re-checked), `PriceSummary` (total = subtotal − discount), `CheckoutRepository.placeOrder` and its implementations (take the code), `ApiClient` (a POST), `app.dart`, and the cart screen (field and discount row).
- **Untouched:** `MenuCubit`, the menu screen, the menu models and the cart bar.

## Design questions

**1. State shape.** The menu screen reads two Cubits that change for different reasons. `MenuCubit` holds a sealed loading, loaded and failure state, because each case has different data and the screen must handle all three. `CartCubit` combines the cart lines with a sealed checkout status in one class, because the lines exist in every status, and an item's quantity is read from the lines, not stored separately. Tapping "+" rebuilds only that row's quantity control (a `BlocSelector` on its quantity and the submitting flag) and the cart bar, which I measured with `debugOnRebuildDirtyWidget`. The cost: while an order is sending, every built menu row's quantity control rebuilds twice, and the cart screen rebuilds as a whole on each change.

**2. API contract.** Before implementation began, I would push for a menu endpoint shaped for this screen: categories in display order with display names, each holding its items. DummyJSON returns one flat product list with a category slug, so the app groups items and turns `mens-shirts` into "Mens Shirts" itself. With the grouped shape, `_groupByCategory` and `_displayName` would be deleted, and category names would come from the server, so renaming one ("Men's Shirts", not "Mens Shirts") would not need an app release.

**3. Async edge cases.** `CartCubit` is provided above `MaterialApp`, so going back cancels nothing. The request continues, the cart cannot be edited, the menu's cart bar shows "Placing order…", and the result is shown as a snackbar on whichever screen the user is on. An app in the background applies the result when it arrives: a failed order keeps the cart, and a success leaves only a snackbar, so a customer who returns late sees an empty cart with no confirmation. Double submission is prevented in `CartCubit.placeOrder`, which checks whether an order is already submitting and marks it as submitting before its first `await`. This only stops a user's concurrent taps: a retry after a timeout could still duplicate an order, which would need a server idempotency key.

**4. With two more hours.** I would save the cart to shared preferences and reconcile it against a fresh menu on launch. Saving alone would cause problems: the saved cart could hold an item whose price has changed or that has since sold out, so the reconcile step is the real work.

**5. Scaling to 2,000 items and 40 categories.** What slows down first is the data: it's one unpaginated request, decoded and grouped on the UI thread. The UX also gets worse, with 40 tabs in one row and no search bar to find items. For images, one row of each later category is mounted at start, so about 40 thumbnails start loading at once, with no disk cache. I would load one category at a time, add search, and cache images on disk with `cached_network_image`.

## Trade-offs and known limits

- **Fixed row heights.** The tab row needs each category's scroll offset before its rows are built, so row height is computed from the theme and the text-size setting (134 px by default, about four rows on a phone). The cost: a name is cut at two lines and a description at one or two.
- **Availability by exception.** An item that can be ordered shows a "+". A sold-out item is dimmed and says "Sold out". The app reads the stock count only to decide that, and does not cap quantities: a real server is the authority.
- **Removing a cart line.** Swipe it to the left, or use minus at quantity 1. There is no bin button per line. A swipe has no visible hint and no undo. The line leaves the cart as soon as it has slid away (about 0.2 s); an order placed before that includes it and the line springs back, so an order always matches the screen.
- **Opening the cart never places an order.** "Place order" sits where the menu's "View cart" bar is, so the button ignores taps until the cart screen has arrived, and the bar ignores taps while the cart closes. Tests cover both.
- **Six pieces of text stop growing** at 1.3 or 1.5 times, where a fixed height would otherwise cut them off: tab labels, the cart bar, the order summary, snackbars, the stepper's number and "Sold out". Everything else, including the pinned category header, has no limit.
- **In memory only.** The cart is lost if the app is killed. A malformed menu item is skipped and logged in debug; the load fails only if none can be read.
- **Run on:** a Samsung Galaxy S21 (Android 14), an iOS 18.3 simulator (debug) and an Android API 35 emulator (release). Not run on a physical iPhone or on API 26.

## Testing

The brief said tests were not required. I kept two files, 15 tests, because duplicate submission is the one async requirement the brief names. `test/cart_cubit_test.dart` covers the guard and the cart rules with a fake checkout that stays in flight until the test completes it. `test/checkout_flow_test.dart` drives the real app with fake repositories: the order result on either screen, the two tap guards, and swipe-to-remove. With more time: a tab-jump test at several text sizes, and repository tests for each error mapping.
