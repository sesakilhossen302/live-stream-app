import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/agora_live_controller.dart';
import 'host_live_screen.dart';
import 'dart:convert';

class GoLiveSetupScreen extends StatefulWidget {
  const GoLiveSetupScreen({super.key});

  @override
  State<GoLiveSetupScreen> createState() => _GoLiveSetupScreenState();
}

class _GoLiveSetupScreenState extends State<GoLiveSetupScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _startingBidController = TextEditingController(text: "100");
  final _bidIncrementController = TextEditingController(text: "5");
  int _timerDuration = 60;

  List<Map<String, dynamic>> _myProducts = [];
  Map<String, dynamic>? _selectedProduct;
  bool _loadingProducts = true;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _loadMyProducts();
  }

  Future<void> _loadMyProducts() async {
    try {
      final apiClient = Get.find<ApiClient>();
      final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey) ?? "";
      final res = await apiClient.getData("${ApiUrl.products}?sellerId=$userId");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body['products'] ?? body['result'] ?? [];
        if (data is List) {
          setState(() {
            _myProducts = data.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Load products error: $e");
    } finally {
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _goLive() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Get.snackbar("Required", "Please enter a stream title", snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (title.length < 3) {
      Get.snackbar("Too Short", "Title must be at least 3 characters long", snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _isStarting = true);

    final pTitle = _selectedProduct?['title']?.toString() ?? "";
    final rawImgs = _selectedProduct?['images'] ?? _selectedProduct?['image'] ?? _selectedProduct?['coverImage'];
    String pImage = "";
    if (rawImgs is List && rawImgs.isNotEmpty) {
      pImage = rawImgs[0]?.toString() ?? "";
    } else if (rawImgs != null) {
      pImage = rawImgs.toString();
    }

    final ctrl = Get.put(AgoraLiveController(), permanent: true);
    final success = await ctrl.startStream(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      productId: _selectedProduct?['_id']?.toString() ?? "",
      startingBid: double.tryParse(_startingBidController.text) ?? 100,
      bidIncrement: double.tryParse(_bidIncrementController.text) ?? 5,
      timerDuration: _timerDuration,
      productTitle: pTitle,
      productImage: pImage,
    );

    setState(() => _isStarting = false);

    if (success) {
      Get.off(() => const HostLiveScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 22.sp),
            onPressed: () => Get.back(),
          ),
          title: Text("Go Live Setup",
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Preview Icon
              Center(
                child: Container(
                  width: 100.r,
                  height: 100.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)],
                    ),
                  ),
                  child: Icon(Icons.videocam_rounded, color: Colors.white, size: 48.sp),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8.r, height: 8.r, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      SizedBox(width: 8.w),
                      Text("LIVE", style: TextStyle(color: Colors.red, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Title
              _sectionLabel("Stream Title *"),
              SizedBox(height: 10.h),
              _inputField(_titleController, "e.g. Rare Card Break Live!"),
              SizedBox(height: 20.h),

              // Description
              _sectionLabel("Description"),
              SizedBox(height: 10.h),
              _inputField(_descController, "Tell viewers what you're selling...", maxLines: 3),
              SizedBox(height: 24.h),

              // Select Product
              _sectionLabel("Select Product to Auction"),
              SizedBox(height: 10.h),
              _loadingProducts
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B9BFF)))
                  : _myProducts.isEmpty
                      ? Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161622),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.white38, size: 20.sp),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  "No products found. Create a trade listing first.",
                                  style: TextStyle(color: Colors.white38, fontSize: 13.sp),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          height: 130.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _myProducts.length,
                            itemBuilder: (context, i) {
                              final p = _myProducts[i];
                              final isSelected = _selectedProduct?['_id'] == p['_id'];
                              final rawImgs = p['images'] ?? p['image'] ?? p['coverImage'];
                              String imgUrl = "";
                              if (rawImgs is List && rawImgs.isNotEmpty) {
                                imgUrl = rawImgs[0]?.toString() ?? "";
                              } else if (rawImgs != null) {
                                imgUrl = rawImgs.toString();
                              }

                              return GestureDetector(
                                onTap: () => setState(() => _selectedProduct = p),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 110.w,
                                  margin: EdgeInsets.only(right: 12.w),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF8B9BFF).withValues(alpha: 0.2) : const Color(0xFF161622),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF8B9BFF) : Colors.white10,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 60.r,
                                        height: 60.r,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: () {
                                          if (imgUrl.isEmpty) {
                                            return Icon(Icons.image, color: Colors.white24, size: 24.sp);
                                          }
                                          if (imgUrl.startsWith('data:image/') && imgUrl.contains('base64,')) {
                                            try {
                                              final bytes = base64Decode(imgUrl.split('base64,').last);
                                              return Image.memory(bytes, fit: BoxFit.cover);
                                            } catch (_) {
                                              return Icon(Icons.image, color: Colors.white24, size: 24.sp);
                                            }
                                          }
                                          final fullUrl = imgUrl.startsWith('http')
                                              ? imgUrl
                                              : "${ApiUrl.imageBaseUrl}${imgUrl.startsWith('/') ? imgUrl : '/$imgUrl'}";
                                          return Image.network(
                                            fullUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 24.sp),
                                          );
                                        }(),
                                      ),
                                      SizedBox(height: 8.h),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                                        child: Text(
                                          p['title']?.toString() ?? "Product",
                                          style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w800),
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

              SizedBox(height: 24.h),

              // Starting Bid & Bid Increment
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel("Starting Bid (\$)"),
                        SizedBox(height: 10.h),
                        _inputField(_startingBidController, "100", keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel("Bid Increment (\$)"),
                        SizedBox(height: 10.h),
                        _inputField(_bidIncrementController, "5", keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Bid Timer
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("Bid Timer"),
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButton<int>(
                      value: _timerDuration,
                      dropdownColor: const Color(0xFF161622),
                      underline: const SizedBox.shrink(),
                      isExpanded: true,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      items: [30, 60, 120, 180, 300].map((val) {
                        return DropdownMenuItem(value: val, child: Text("${val}s"));
                      }).toList(),
                      onChanged: (val) => setState(() => _timerDuration = val ?? 60),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 40.h),

              // Go Live Button
              GestureDetector(
                onTap: _isStarting ? null : _goLive,
                child: Container(
                  width: double.infinity,
                  height: 60.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)],
                    ),
                    borderRadius: BorderRadius.circular(30.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.4),
                        blurRadius: 20.r,
                        spreadRadius: 2.r,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isStarting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_rounded, color: Colors.white, size: 22.sp),
                              SizedBox(width: 10.w),
                              Text("Go Live Now",
                                  style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w900)),
                            ],
                          ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(color: Colors.white60, fontSize: 12.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5));
  }

  Widget _inputField(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _startingBidController.dispose();
    _bidIncrementController.dispose();
    super.dispose();
  }
}
