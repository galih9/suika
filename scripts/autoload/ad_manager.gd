extends Node

## Central AdMob manager handling top banner ads and rewarded video ads for skin unlocks.
## Set USE_TEST_ADS to false and populate PROD_* ad unit IDs before releasing to production.

signal sdk_initialized
signal banner_height_changed(height_pixels: int)
signal rewarded_ad_loaded
signal rewarded_ad_earned(context_id: String)
signal rewarded_ad_closed(context_id: String, earned: bool)
signal rewarded_ad_failed(context_id: String, reason: String)

const USE_TEST_ADS := true

const TEST_BANNER_ANDROID := "ca-app-pub-3940256099942544/9214589741"
const TEST_BANNER_IOS := "ca-app-pub-3940256099942544/2934735716"
const TEST_REWARDED_ANDROID := "ca-app-pub-3940256099942544/5224354917"
const TEST_REWARDED_IOS := "ca-app-pub-3940256099942544/1712485313"

const PROD_BANNER_ANDROID := ""
const PROD_BANNER_IOS := ""
const PROD_REWARDED_ANDROID := ""
const PROD_REWARDED_IOS := ""

const REWARDED_LOAD_TIMEOUT := 8.0
const BANNER_RETRY_DELAY := 15.0
const REWARDED_RETRY_DELAY := 10.0

var _init_listener: OnInitializationCompleteListener
var _is_initialized: bool = false

var _banner_view: AdView
var _banner_listener: AdListener
var _banner_wanted: bool = false
var _banner_loaded: bool = false
var _banner_visible: bool = false
var _banner_loading: bool = false
var _banner_retry_scheduled: bool = false
var _banner_height_pixels: int = 0
var _simulated_banner_height_px: int = -1

var _rewarded_ad: RewardedAd
var _rewarded_load_callback: RewardedAdLoadCallback
var _rewarded_content_callback: FullScreenContentCallback
var _rewarded_listener: OnUserEarnedRewardListener
var _rewarded_loading: bool = false
var _rewarded_retry_scheduled: bool = false
var _show_rewarded_when_loaded: bool = false
var _is_rewarded_showing: bool = false
var _pending_reward_context: String = ""
var _current_reward_earned: bool = false
var _rewarded_timeout_token: int = 0

var _test_rewarded_handler: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_ads_runtime_supported():
		return
	_configure_editor_mocks_for_pause()
	_initialize_sdk()


func _exit_tree() -> void:
	_destroy_banner()
	_destroy_rewarded_ad()


func is_ads_runtime_supported() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		return true
	return OS.has_feature("editor")


func get_banner_ad_unit_id() -> String:
	var is_ios := OS.get_name() == "iOS"
	var prod := PROD_BANNER_IOS if is_ios else PROD_BANNER_ANDROID
	var test := TEST_BANNER_IOS if is_ios else TEST_BANNER_ANDROID
	if USE_TEST_ADS or OS.is_debug_build() or prod.is_empty():
		return test
	return prod


func get_rewarded_ad_unit_id() -> String:
	var is_ios := OS.get_name() == "iOS"
	var prod := PROD_REWARDED_IOS if is_ios else PROD_REWARDED_ANDROID
	var test := TEST_REWARDED_IOS if is_ios else TEST_REWARDED_ANDROID
	if USE_TEST_ADS or OS.is_debug_build() or prod.is_empty():
		return test
	return prod


func _configure_editor_mocks_for_pause() -> void:
	if not OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	var mock_factory = load("res://addons/admob/internal/mock/mock_admob_factory.gd")
	if mock_factory == null:
		return
	for plugin_name in ["PoingGodotAdMob", "PoingGodotAdMobAdView", "PoingGodotAdMobRewardedAd"]:
		var mock_node = mock_factory.get_mock_plugin(plugin_name)
		if mock_node is Node:
			(mock_node as Node).process_mode = Node.PROCESS_MODE_ALWAYS


func _initialize_sdk() -> void:
	_init_listener = OnInitializationCompleteListener.new()
	_init_listener.on_initialization_complete = _on_initialization_complete
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(_init_listener)


func _on_initialization_complete(_status: InitializationStatus) -> void:
	_is_initialized = true
	sdk_initialized.emit()
	preload_rewarded_ad()
	if _banner_wanted:
		_ensure_banner_loaded()


# --- Banner Ads ------------------------------------------------------------------------------

func show_banner() -> void:
	_banner_wanted = true
	if not is_ads_runtime_supported() or not _is_initialized:
		return
	if _is_rewarded_showing:
		return
	if _banner_view == null:
		_ensure_banner_loaded()
	elif _banner_loaded:
		_banner_view.show()
		_banner_visible = true
		_refresh_banner_height()


func hide_banner() -> void:
	_banner_wanted = false
	_banner_visible = false
	if _banner_view != null:
		_banner_view.hide()
	_refresh_banner_height()


func _ensure_banner_loaded() -> void:
	if not is_ads_runtime_supported() or not _is_initialized:
		return
	if _banner_loading:
		return
	if _banner_view == null:
		_create_and_load_banner()
	elif not _banner_loaded:
		_banner_loading = true
		_banner_view.load_ad(AdRequest.new())


func _create_and_load_banner() -> void:
	_destroy_banner()
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	if ad_size == null or ad_size.height <= 0:
		ad_size = AdSize.BANNER

	_banner_view = AdView.new(get_banner_ad_unit_id(), ad_size, AdPosition.TOP)
	_banner_listener = AdListener.new()
	_banner_listener.on_ad_loaded = _on_banner_loaded
	_banner_listener.on_ad_failed_to_load = _on_banner_failed_to_load
	_banner_listener.on_ad_closed = _on_banner_closed
	_banner_view.ad_listener = _banner_listener

	_banner_loaded = false
	_banner_visible = false
	_banner_loading = true
	_banner_view.hide()
	_banner_view.load_ad(AdRequest.new())


func _on_banner_loaded() -> void:
	_banner_loading = false
	_banner_loaded = true
	if _banner_view == null:
		return
	if _banner_wanted and not _is_rewarded_showing:
		_banner_view.show()
		_banner_visible = true
	else:
		_banner_view.hide()
		_banner_visible = false
	_refresh_banner_height()


func _on_banner_failed_to_load(_error: LoadAdError) -> void:
	_banner_loading = false
	_banner_loaded = false
	_banner_visible = false
	_refresh_banner_height()
	_schedule_banner_retry()


func _on_banner_closed() -> void:
	if _banner_view != null and _banner_view.get_height_in_pixels() <= 0:
		_banner_visible = false
	_refresh_banner_height()


func _schedule_banner_retry() -> void:
	if _banner_retry_scheduled or not is_inside_tree():
		return
	_banner_retry_scheduled = true
	var timer := get_tree().create_timer(BANNER_RETRY_DELAY, true)
	timer.timeout.connect(func() -> void:
		_banner_retry_scheduled = false
		if not is_inside_tree() or not _banner_wanted or _banner_loaded:
			return
		_ensure_banner_loaded()
	)


func _destroy_banner() -> void:
	if _banner_view != null:
		_banner_view.destroy()
		_banner_view = null
	_banner_listener = null
	_banner_loaded = false
	_banner_visible = false
	_banner_loading = false
	_refresh_banner_height()


func _compute_banner_height_pixels() -> int:
	if _simulated_banner_height_px >= 0:
		return _simulated_banner_height_px
	if not _banner_visible or not _banner_loaded or _banner_view == null:
		return 0
	return maxi(_banner_view.get_height_in_pixels(), 0)


func _refresh_banner_height() -> void:
	var next_px := _compute_banner_height_pixels()
	if next_px != _banner_height_pixels:
		_banner_height_pixels = next_px
		banner_height_changed.emit(_banner_height_pixels)


func get_banner_height_pixels() -> int:
	return _compute_banner_height_pixels()


func get_banner_height_in_viewport(vp: Viewport) -> float:
	var px := get_banner_height_pixels()
	if px <= 0:
		return 0.0
	if vp == null:
		return float(px)
	var win_size := DisplayServer.window_get_size()
	if win_size.y <= 0:
		return float(px)
	var vp_height := vp.get_visible_rect().size.y
	if vp_height <= 0.0:
		return float(px)
	return float(px) * (vp_height / float(win_size.y))


# --- Rewarded Ads ----------------------------------------------------------------------------

func is_rewarded_ad_ready() -> bool:
	return _rewarded_ad != null and not _is_rewarded_showing


func preload_rewarded_ad() -> void:
	if not is_ads_runtime_supported() or not _is_initialized:
		return
	if _rewarded_loading or _rewarded_ad != null:
		return

	_rewarded_loading = true
	_rewarded_load_callback = RewardedAdLoadCallback.new()
	_rewarded_load_callback.on_ad_loaded = _on_rewarded_ad_loaded
	_rewarded_load_callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load

	# RewardedAdLoader binds a per-load UID, so instantiate a fresh loader per request.
	var loader := RewardedAdLoader.new()
	loader.load(get_rewarded_ad_unit_id(), AdRequest.new(), _rewarded_load_callback)


func show_rewarded_ad(context_id: String) -> void:
	if _test_rewarded_handler.is_valid():
		_test_rewarded_handler.call(context_id)
		return
	if _is_rewarded_showing:
		return
	if not is_ads_runtime_supported():
		rewarded_ad_failed.emit(context_id, "Ads unavailable")
		return

	_pending_reward_context = context_id
	_current_reward_earned = false

	if _rewarded_ad != null:
		_present_loaded_rewarded_ad()
		return

	_show_rewarded_when_loaded = true
	_rewarded_timeout_token += 1
	var token := _rewarded_timeout_token
	if is_inside_tree():
		var timer := get_tree().create_timer(REWARDED_LOAD_TIMEOUT, true)
		timer.timeout.connect(func() -> void:
			if token != _rewarded_timeout_token or not _show_rewarded_when_loaded or _is_rewarded_showing:
				return
			var timed_out_ctx := _pending_reward_context
			_show_rewarded_when_loaded = false
			_pending_reward_context = ""
			rewarded_ad_failed.emit(timed_out_ctx, "Rewarded ad timed out")
		)

	if _is_initialized and not _rewarded_loading:
		preload_rewarded_ad()


func cancel_pending_rewarded_ad() -> void:
	if _show_rewarded_when_loaded and not _is_rewarded_showing:
		_show_rewarded_when_loaded = false
		_pending_reward_context = ""
		_rewarded_timeout_token += 1


func _on_rewarded_ad_loaded(ad: RewardedAd) -> void:
	_rewarded_loading = false
	_rewarded_ad = ad

	_rewarded_content_callback = FullScreenContentCallback.new()
	_rewarded_content_callback.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed
	_rewarded_content_callback.on_ad_failed_to_show_full_screen_content = _on_rewarded_failed_to_show
	_rewarded_ad.full_screen_content_callback = _rewarded_content_callback

	rewarded_ad_loaded.emit()

	if _show_rewarded_when_loaded and not _is_rewarded_showing:
		_show_rewarded_when_loaded = false
		_rewarded_timeout_token += 1
		_present_loaded_rewarded_ad()


func _on_rewarded_ad_failed_to_load(error: LoadAdError) -> void:
	_rewarded_loading = false
	if _show_rewarded_when_loaded:
		var ctx := _pending_reward_context
		_show_rewarded_when_loaded = false
		_pending_reward_context = ""
		_rewarded_timeout_token += 1
		rewarded_ad_failed.emit(ctx, error.message if error != null else "Load failed")
	_schedule_rewarded_retry()


func _schedule_rewarded_retry() -> void:
	if _rewarded_retry_scheduled or not is_inside_tree():
		return
	_rewarded_retry_scheduled = true
	var timer := get_tree().create_timer(REWARDED_RETRY_DELAY, true)
	timer.timeout.connect(func() -> void:
		_rewarded_retry_scheduled = false
		if not is_inside_tree():
			return
		preload_rewarded_ad()
	)


func _present_loaded_rewarded_ad() -> void:
	if _rewarded_ad == null:
		return
	_is_rewarded_showing = true
	_rewarded_timeout_token += 1
	if _banner_view != null and _banner_visible:
		_banner_view.hide()
		_banner_visible = false
		_refresh_banner_height()

	_rewarded_listener = OnUserEarnedRewardListener.new()
	_rewarded_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_current_reward_earned = true
		rewarded_ad_earned.emit(_pending_reward_context)

	_rewarded_ad.show(_rewarded_listener)


func _on_rewarded_dismissed() -> void:
	var ctx := _pending_reward_context
	var earned := _current_reward_earned
	_destroy_rewarded_ad()
	_is_rewarded_showing = false
	_show_rewarded_when_loaded = false
	_pending_reward_context = ""
	_current_reward_earned = false
	_restore_banner_after_rewarded()
	rewarded_ad_closed.emit(ctx, earned)
	preload_rewarded_ad()


func _on_rewarded_failed_to_show(error: AdError) -> void:
	var ctx := _pending_reward_context
	_destroy_rewarded_ad()
	_is_rewarded_showing = false
	_show_rewarded_when_loaded = false
	_pending_reward_context = ""
	_current_reward_earned = false
	_restore_banner_after_rewarded()
	rewarded_ad_failed.emit(ctx, error.message if error != null else "Failed to show")
	preload_rewarded_ad()


func _restore_banner_after_rewarded() -> void:
	if _banner_wanted:
		show_banner()


func _destroy_rewarded_ad() -> void:
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null
	_rewarded_content_callback = null
	_rewarded_listener = null


# --- Test Helpers ----------------------------------------------------------------------------

func set_simulated_banner_height_pixels(px: int) -> void:
	_simulated_banner_height_px = px
	_refresh_banner_height()


func set_test_rewarded_handler(handler: Callable) -> void:
	_test_rewarded_handler = handler
