//
//  LocalizationManager.swift
//  PureLibrary
//
//  Runtime Bilingual (Vietnamese / English) Localization Manager.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI
import Combine

public final class LocalizationManager: ObservableObject, @unchecked Sendable {
    public static let shared = LocalizationManager()
    
    private let userDefaultsKey = "app_language"
    
    @Published public private(set) var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: userDefaultsKey)
        }
    }
    
    public init() {
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey)
        self.currentLanguage = saved ?? "vi"
    }
    
    public func setLanguage(_ code: String) {
        guard code == "vi" || code == "en" else { return }
        currentLanguage = code
    }
    
    public func t(_ key: String) -> String {
        if let dict = strings[currentLanguage], let val = dict[key] {
            return val
        }
        if let fallbackDict = strings["en"], let val = fallbackDict[key] {
            return val
        }
        return key
    }
    
    private let strings: [String: [String: String]] = [
        "vi": [
            // 4 Main Tabs
            "tab_organize": "Tổ chức",
            "tab_ai_clean": "Dọn AI",
            "tab_albums": "Albums",
            "tab_settings": "Cài đặt",
            
            // Organize Tab
            "seg_unsorted": "Chưa phân loại",
            "seg_albums": "Albums",
            "card_random": "Ngẫu nhiên",
            "card_random_sub": "Duyệt & lọc nhanh",
            "card_this_week": "Tuần này",
            "card_this_week_sub": "Ảnh mới chụp 7 ngày",
            "row_all_unsorted": "Tất cả chưa phân loại",
            "row_unsorted_videos": "Video chưa phân loại",
            "row_unsorted_screenshots": "Ảnh màn hình chưa phân loại",
            "section_monthly_timeline": "DÒNG THỜI GIAN THEO THÁNG",
            "empty_library_title": "Đang đồng bộ thư viện ảnh",
            "empty_library_sub": "Hãy cấp quyền truy cập Ảnh để ứng dụng tự động sắp xếp theo tháng.",
            "btn_grant_access": "Cho phép truy cập Ảnh",
            
            // Storage Bar
            "device_storage": "DUNG LƯỢNG THIẾT BỊ",
            "storage_used_system": "Đã dùng",
            "storage_reclaimable": "Có thể dọn",
            "storage_free": "Còn trống",
            "storage_freeable_suffix": "có thể giải phóng",
            
            // AI Clean Tab
            "app_title": "PureLibrary",
            "app_name": "PureLibrary AI Cleaner",
            "app_version": "2.1.0 (Build 2026.10)",
            "reclaimable_capacity": "CÓ THỂ DỌN DẸP NGAY",
            "ai_syncing_badge": "Đang phân tích ảnh mới...",
            "ai_synced_badge": "Đã đồng bộ toàn bộ thư viện",
            "btn_smart_clean_all": "CHỌN TẤT CẢ ẢNH TRÙNG & ẢNH MỜ",
            "btn_delete_staged_now": "XÓA NGAY",
            "filter_duplicates": "Ảnh trùng",
            "filter_blurry": "Ảnh mờ",
            "filter_screenshots": "Màn hình & Đơn",
            "filter_videos": "Video lớn",
            "btn_keep_best_clean_rest": "Giữ ảnh đẹp nhất • Xóa ảnh trùng",
            "btn_stage_all_category": "Chọn xóa toàn bộ mục này",
            "clean_empty_group": "Tuyệt vời! Không có ảnh rác nào trong mục này.",
            "ready": "Sẵn sàng",
            "scan_cancelled": "Đã tạm dừng",
            "items_count_suffix": "ảnh",
            "groups_count_suffix": "nhóm",
            
            // Categories
            "cat_similar_burst_title": "Ảnh trùng lặp & Chụp liên tục",
            "cat_similar_burst_sub": "Tự động giữ tấm nét nhất, gom ảnh trùng",
            "cat_blurry_title": "Ảnh mờ & Out nét",
            "cat_blurry_sub": "Ảnh rung tay, nhòe hoặc chụp hỏng",
            "cat_screenshots_title": "Ảnh chụp màn hình & Hóa đơn",
            "cat_screenshots_sub": "Biên lai, hóa đơn và chụp màn hình",
            "cat_videos_title": "Video dung lượng lớn",
            "cat_videos_sub": "Video chiếm nhiều bộ nhớ nhất",
            
            // Albums Tab
            "albums_title": "Albums trên iPhone",
            "btn_new_album": "Tạo Album mới",
            "new_album_prompt_title": "Tạo Album mới",
            "new_album_placeholder": "Nhập tên Album...",
            "btn_create": "Tạo",
            "no_albums_title": "Chưa có Album cá nhân",
            "no_albums_sub": "Bấm 'Tạo Album mới' để phân loại ảnh nhanh chóng.",
            "added_to_album_toast": "Đã thêm vào Album",
            
            // Statuses
            "status_sharp": "Sắc nét",
            "status_blurry": "Bị mờ",
            "status_duplicate": "Ảnh trùng",
            "status_screenshot": "Màn hình / Đơn",
            "status_pocket": "Ảnh chụp hỏng",
            "status_normal": "Đạt chuẩn",
            
            // Settings
            "settings_title": "Cài đặt",
            "section_language": "Ngôn ngữ hiển thị",
            "lang_vietnamese": "Tiếng Việt",
            "lang_english": "English",
            "section_blur_sensitivity": "Độ nhạy nhận diện ảnh mờ",
            "blur_strict": "Nghiêm ngặt",
            "blur_balanced": "Cân bằng (Khuyên dùng)",
            "blur_conservative": "Thận trọng",
            "blur_strict_desc": "Lọc kỹ hơn, phát hiện cả ảnh hơi mềm hoặc out nét nhẹ.",
            "blur_balanced_desc": "Mức chuẩn cân đối cho thư viện ảnh hàng ngày.",
            "blur_conservative_desc": "Chỉ lọc các ảnh bị rung lắc mạnh hoặc nhòe nặng.",
            "btn_rescan_library": "Đồng bộ & Phân tích lại",
            "section_cache": "Bộ nhớ đệm thông minh",
            "cached_entries": "Số ảnh đã lưu kết quả AI:",
            "btn_clear_cache": "Làm mới bộ nhớ đệm",
            "clear_cache_confirm": "Làm mới dữ liệu đệm để phân tích lại thư viện ảnh?",
            "btn_confirm": "Đồng ý",
            "btn_cancel": "Hủy",
            
            // Developer Info
            "section_dev_info": "Thông tin ứng dụng & Nhà phát triển",
            "label_app_name": "Ứng dụng:",
            "label_version": "Phiên bản:",
            "label_developer": "Nhà phát triển (Developer):",
            "val_developer": "ace4youblade",
            
            // Grid & Inspector
            "grid_select_all": "Chọn tất cả",
            "grid_deselect_all": "Bỏ chọn",
            "grid_stage_selected": "Đưa vào giỏ xóa",
            "grid_selected_count": "Đã chọn:",
            "no_items_in_category": "Không có ảnh nào trong mục này.",
            "inspector_title": "Xem chi tiết",
            "inspector_zoom_hint": "Chạm đúp hoặc dùng 2 ngón tay phóng to (1x - 5x)",
            "sharpness_label": "Độ nét:",
            "face_label": "Khuôn mặt:",
            "exposure_label": "Ánh sáng:",
            "resolution_label": "Độ phân giải:",
            "file_size_label": "Dung lượng:",
            "date_taken_label": "Ngày chụp:",
            "classification_label": "Trạng thái:",
            "reason_label": "Ghi chú:",
            "btn_keep": "Giữ lại",
            "btn_stage_to_trash": "Cho vào giỏ xóa",
            "staged_badge": "CHỜ XÓA",
            "best_badge": "ĐẸP NHẤT",
            
            // Score Breakdown
            "best_shot_winner": "ẢNH ĐẸP NHẤT NHÓM",
            "composite_label": "ĐÁNH GIÁ",
            "score_sharpness_row": "Độ sắc nét chi tiết",
            "score_face_row": "Khuôn mặt & Ánh mắt",
            "score_exposure_row": "Cân bằng ánh sáng",
            "score_aesthetic_row": "Bố cục & Màu sắc",
            "motion_blur_penalty_row": "Bị rung nhòe chuyển động",
            
            // Trash Staging
            "trash_basket_title": "Giỏ chờ xóa",
            "staged_for_trash_header": "DUNG LƯỢNG SẼ GIẢI PHÓNG",
            "trash_safety_note": "Ảnh xóa sẽ chuyển vào 'Đã xóa gần đây' của iOS trong 30 ngày.",
            "trash_empty_title": "Giỏ xóa đang trống",
            "trash_empty_sub": "Vuốt lên trên ảnh hoặc chọn ảnh trùng để đưa vào giỏ xóa.",
            "btn_confirm_delete_prefix": "XÓA VĨNH VIỄN",
            "alert_confirm_delete_title": "Xác nhận xóa ảnh",
            "btn_delete_items": "Xóa ảnh",
            "alert_confirm_delete_msg": "iOS sẽ xin quyền xác nhận và chuyển các ảnh này vào Đã xóa gần đây.",
            
            // Redesigned Swipe / Triage View
            "swipe_culler_title": "Duyệt & Phân loại",
            "swipe_hint_bar": "Vuốt lên/trái để Xóa • Vuốt phải để Giữ • Chạm Album để thêm",
            "swipe_queue_remaining": "CÒN LẠI:",
            "swipe_staged_suffix": "TRONG GIỎ XÓA",
            "btn_undo": "Hoàn tác",
            "swipe_queue_cleaned": "Đã duyệt hết danh sách!",
            "swipe_items_staged_sub": "ảnh đã được đưa vào giỏ xóa.",
            "btn_proceed_trash": "MỞ GIỎ XÓA ĐỂ DỌN NGAY",
            "btn_stage_short": "XÓA",
            "btn_keep_short": "GIỮ LẠI",
            "stamp_stage_trash": "XÓA ẢNH",
            "stamp_keep_photo": "GIỮ LẠI",
            "add_to_album_bar_label": "Thêm nhanh vào Album:",
            
            // Cluster Compare
            "cluster_compare_title": "So sánh nhóm ảnh trùng",
            "cluster_of_label": "NHÓM",
            "btn_set_best": "Chọn giữ tấm này",
            "ai_winner_badge": "ĐẸP NHẤT",
            "reclaimable_in_cluster": "DUNG LƯỢNG DỌN ĐƯỢC:",
            "btn_keep_best_stage_rest": "GIỮ ẢNH ĐẸP NHẤT & XÓA ẢNH TRÙNG",
            "no_clusters_title": "Không có nhóm ảnh trùng lặp",
            "no_clusters_sub": "Thư viện của bạn đã gọn gàng.",
            "btn_close": "Đóng"
        ],
        "en": [
            // 4 Main Tabs
            "tab_organize": "Organize",
            "tab_ai_clean": "AI Clean",
            "tab_albums": "Albums",
            "tab_settings": "Settings",
            
            // Organize Tab
            "seg_unsorted": "Unsorted",
            "seg_albums": "Albums",
            "card_random": "Random",
            "card_random_sub": "Shuffle & rapid triage",
            "card_this_week": "This Week",
            "card_this_week_sub": "Captured in last 7 days",
            "row_all_unsorted": "All Unsorted",
            "row_unsorted_videos": "Unsorted Videos",
            "row_unsorted_screenshots": "Unsorted Screenshots",
            "section_monthly_timeline": "MONTHLY TIMELINE",
            "empty_library_title": "Syncing Photo Library",
            "empty_library_sub": "Allow Photo Library access to automatically organize photos by month.",
            "btn_grant_access": "Allow Photo Access",
            
            // Storage Bar
            "device_storage": "DEVICE STORAGE",
            "storage_used_system": "Used",
            "storage_reclaimable": "Cleanable",
            "storage_free": "Free",
            "storage_freeable_suffix": "cleanable",
            
            // AI Clean Tab
            "app_title": "PureLibrary",
            "app_name": "PureLibrary AI Cleaner",
            "app_version": "2.1.0 (Build 2026.10)",
            "reclaimable_capacity": "READY TO CLEAN",
            "ai_syncing_badge": "Analyzing new photos in background...",
            "ai_synced_badge": "Library fully synced",
            "btn_smart_clean_all": "STAGE ALL DUPLICATES & BLURRY",
            "btn_delete_staged_now": "DELETE NOW",
            "filter_duplicates": "Duplicates",
            "filter_blurry": "Blurry",
            "filter_screenshots": "Screenshots",
            "filter_videos": "Large Videos",
            "btn_keep_best_clean_rest": "Keep Best • Trash Duplicates",
            "btn_stage_all_category": "Select All for Deletion",
            "clean_empty_group": "All clean! No clutter found in this category.",
            "ready": "Ready",
            "scan_cancelled": "Paused",
            "items_count_suffix": "items",
            "groups_count_suffix": "groups",
            
            // Categories
            "cat_similar_burst_title": "Similar & Burst Groups",
            "cat_similar_burst_sub": "Auto-picks sharpest shot, groups duplicates",
            "cat_blurry_title": "Blurry & Out of Focus",
            "cat_blurry_sub": "Camera shake, defocus, or pocket shots",
            "cat_screenshots_title": "Screenshots & Receipts",
            "cat_screenshots_sub": "Old screen captures & paper bills",
            "cat_videos_title": "Large Videos",
            "cat_videos_sub": "Biggest storage-hogging recordings",
            
            // Albums Tab
            "albums_title": "My Albums",
            "btn_new_album": "New Album",
            "new_album_prompt_title": "Create New Album",
            "new_album_placeholder": "Album title...",
            "btn_create": "Create",
            "no_albums_title": "No Custom Albums Yet",
            "no_albums_sub": "Tap 'New Album' to create folders and organize your photos.",
            "added_to_album_toast": "Added to Album",
            
            // Statuses
            "status_sharp": "Sharp",
            "status_blurry": "Blurry",
            "status_duplicate": "Duplicate",
            "status_screenshot": "Screenshot",
            "status_pocket": "Blank Frame",
            "status_normal": "Good",
            
            // Settings
            "settings_title": "Settings",
            "section_language": "Display Language",
            "lang_vietnamese": "Tiếng Việt",
            "lang_english": "English",
            "section_blur_sensitivity": "Blur Detection Sensitivity",
            "blur_strict": "Strict",
            "blur_balanced": "Balanced (Recommended)",
            "blur_conservative": "Conservative",
            "blur_strict_desc": "Catches mildly soft shots or slight focus misses.",
            "blur_balanced_desc": "Ideal everyday calibration for iPhone libraries.",
            "blur_conservative_desc": "Only flags heavily blurred or ruined frames.",
            "btn_rescan_library": "Sync & Re-Analyze Library",
            "section_cache": "Smart Analysis Cache",
            "cached_entries": "Cached photo records:",
            "btn_clear_cache": "Reset Analysis Cache",
            "clear_cache_confirm": "Clear cached AI scores and re-analyze your library?",
            "btn_confirm": "Confirm",
            "btn_cancel": "Cancel",
            
            // Developer Info
            "section_dev_info": "Application & Developer Info",
            "label_app_name": "Application:",
            "label_version": "Version:",
            "label_developer": "Developer:",
            "val_developer": "ace4youblade",
            
            // Grid & Inspector
            "grid_select_all": "Select All",
            "grid_deselect_all": "Deselect All",
            "grid_stage_selected": "Move to Trash",
            "grid_selected_count": "Selected:",
            "no_items_in_category": "No photos in this section.",
            "inspector_title": "Photo Detail",
            "inspector_zoom_hint": "Double-tap or pinch (1x - 5x) to inspect",
            "sharpness_label": "Sharpness:",
            "face_label": "Face:",
            "exposure_label": "Exposure:",
            "resolution_label": "Resolution:",
            "file_size_label": "Size:",
            "date_taken_label": "Date:",
            "classification_label": "Status:",
            "reason_label": "Note:",
            "btn_keep": "Keep",
            "btn_stage_to_trash": "Trash",
            "staged_badge": "TRASH",
            "best_badge": "BEST",
            
            // Score Breakdown
            "best_shot_winner": "BEST SHOT IN GROUP",
            "composite_label": "OVERALL",
            "score_sharpness_row": "Optical Detail & Focus",
            "score_face_row": "Face & Eyes Open",
            "score_exposure_row": "Lighting Balance",
            "score_aesthetic_row": "Composition & Color",
            "motion_blur_penalty_row": "Motion Shake Detected",
            
            // Trash Staging
            "trash_basket_title": "Trash Basket",
            "staged_for_trash_header": "SPACE TO BE FREED",
            "trash_safety_note": "Deleted items move to iOS 'Recently Deleted' for 30 days.",
            "trash_empty_title": "Trash Basket is Empty",
            "trash_empty_sub": "Swipe up on photos or stage duplicates to clean them up.",
            "btn_confirm_delete_prefix": "DELETE",
            "alert_confirm_delete_title": "Confirm Deletion",
            "btn_delete_items": "Delete",
            "alert_confirm_delete_msg": "iOS will ask for confirmation to move these items to Recently Deleted.",
            
            // Redesigned Swipe / Triage View
            "swipe_culler_title": "Swipe & Organize",
            "swipe_hint_bar": "Swipe Up/Left to Trash • Swipe Right to Keep • Tap Album to Add",
            "swipe_queue_remaining": "REMAINING:",
            "swipe_staged_suffix": "IN TRASH",
            "btn_undo": "Undo",
            "swipe_queue_cleaned": "All Caught Up!",
            "swipe_items_staged_sub": "photos moved to Trash Basket.",
            "btn_proceed_trash": "OPEN TRASH BASKET",
            "btn_stage_short": "TRASH",
            "btn_keep_short": "KEEP",
            "stamp_stage_trash": "TRASH",
            "stamp_keep_photo": "KEEP",
            "add_to_album_bar_label": "Add to Album:",
            
            // Cluster Compare
            "cluster_compare_title": "Compare Duplicates",
            "cluster_of_label": "GROUP",
            "btn_set_best": "Pick as Best",
            "ai_winner_badge": "BEST SHOT",
            "reclaimable_in_cluster": "SAVINGS IN GROUP:",
            "btn_keep_best_stage_rest": "KEEP BEST & TRASH REST",
            "no_clusters_title": "No Duplicate Groups",
            "no_clusters_sub": "Your library is free of duplicate sets.",
            "btn_close": "Close"
        ]
    ]
}
