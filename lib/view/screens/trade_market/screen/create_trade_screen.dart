import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/create_trade_controller.dart';

class CreateTradeScreen extends GetView<CreateTradeController> {
  const CreateTradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(CreateTradeController());
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Create Trade",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),
              Text(
                "Create Trade",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Curate your exchange. Offer excellence,\nreceive value.",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 40.h),
              _buildSectionTitle("Your Item"),
              SizedBox(height: 8.h),
              Text(
                "Present your masterpiece. High-quality imagery and detailed provenance attract the most prestigious offers.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 24.h),
              _buildUploadBox(),

              SizedBox(height: 32.h),
              _buildInputContainer([
                _buildLabel("Item name"),
                _buildTextField(
                  "e.g. Vintage 1964 Chronograph",
                  controller.itemNameController,
                  prefixIcon: Icon(Icons.bookmark_border_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                ),
                SizedBox(height: 24.h),
                _buildLabel("Description"),
                _buildTextField(
                  "Detail the narrative and specifications of your item...",
                  controller.descriptionController,
                  maxLines: 3,
                  prefixIcon: Icon(Icons.notes_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => _buildSelectable(
                          "Category",
                          controller.selectedCategory.value,
                          () => _showPicker(
                            "Select Category",
                            controller.categories,
                            (val) => controller.setCategory(val),
                          ),
                          leadingIcon: Icons.category_outlined,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Obx(
                        () => _buildSelectable(
                          "Condition",
                          controller.selectedCondition.value,
                          () => _showPicker(
                            "Select Condition",
                            controller.conditions,
                            (val) => controller.setCondition(val),
                          ),
                          leadingIcon: Icons.stars_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                _buildLabel("Estimated value"),
                _buildTextField(
                  "5000",
                  controller.estValueController,
                  keyboardType: TextInputType.number,
                  prefixText: "\$",
                ),
                SizedBox(height: 24.h),

                // ── Shipping Weight (Feature 1) ─────────────────────────────
                _buildLabel("Shipping weight"),
                Container(
                  height: 54.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161622),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.2,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Icon(Icons.scale_outlined, color: const Color(0xFF8B9BFF), size: 18.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: TextField(
                          controller: controller.shippingWeightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: "e.g. 1.5",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.28),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        height: 22.h,
                        width: 1.w,
                        color: Colors.white.withOpacity(0.1),
                        margin: EdgeInsets.symmetric(horizontal: 12.w),
                      ),
                      Obx(() => GestureDetector(
                        onTap: () => _showPicker(
                          "Select Weight Unit",
                          controller.weightUnits,
                          (val) => controller.shippingWeightUnit.value = val,
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B9BFF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFF8B9BFF).withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.shippingWeightUnit.value.toUpperCase(),
                                style: TextStyle(
                                  color: const Color(0xFF8B9BFF),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: const Color(0xFF8B9BFF),
                                size: 16.sp,
                              ),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  "Required for automated shipping label & postage calculation.",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 28.h),

                // ── Buy Now Price ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Buy now price",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            "Allow instant purchase at a fixed price",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() => GestureDetector(
                      onTap: () => controller.enableBuyNow.toggle(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48.w,
                        height: 26.h,
                        decoration: BoxDecoration(
                          color: controller.enableBuyNow.value
                              ? const Color(0xFF8B9BFF)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: controller.enableBuyNow.value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.all(3.r),
                            width: 20.r,
                            height: 20.r,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
                Obx(() => controller.enableBuyNow.value
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          _buildTextField(
                            "e.g. 4500",
                            controller.buyNowPriceController,
                            keyboardType: TextInputType.number,
                            prefixText: "\$",
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B9BFF).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: const Color(0xFF8B9BFF).withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    "Buyers can instantly purchase your item at this price without trade negotiation.",
                                    style: TextStyle(
                                      color: const Color(0xFF8B9BFF).withOpacity(0.9),
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink()),

                SizedBox(height: 28.h),

                // ── Allow Custom Offers (Feature 2) ─────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Allow custom offers",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            "Let buyers submit custom price offers for this item",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() => GestureDetector(
                      onTap: () => controller.allowOffers.toggle(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48.w,
                        height: 26.h,
                        decoration: BoxDecoration(
                          color: controller.allowOffers.value
                              ? const Color(0xFF8B9BFF)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: controller.allowOffers.value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.all(3.r),
                            width: 20.r,
                            height: 20.r,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
                Obx(() => controller.allowOffers.value
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          _buildLabel("Minimum acceptable offer (\$)"),
                          _buildTextField(
                            "Accept offers over e.g. 3500",
                            controller.minOfferAmountController,
                            keyboardType: TextInputType.number,
                            prefixText: "\$",
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            "Offers below this minimum price will be automatically rejected.",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink()),

              ]),

              SizedBox(height: 40.h),
              _buildSectionTitle("What You Want"),
              SizedBox(height: 8.h),
              Text(
                "Define your desire. Whether it's a specific rarity or a broad category, be clear on what completes the swap.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 24.h),
              _buildInputContainer([
                _buildLabel("What you're looking for"),
                _buildTextField(
                  "Seeking modern horology or rare photography...",
                  controller.desiredItemController,
                  maxLines: 2,
                  prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                ),
                SizedBox(height: 24.h),
                Obx(
                  () => _buildSelectable(
                    "Target category",
                    controller.targetCategory.value,
                    () => _showPicker(
                      "Select Target Category",
                      controller.targetCategories,
                      (val) => controller.setTargetCategory(val),
                    ),
                    leadingIcon: Icons.filter_list_rounded,
                  ),
                ),
                SizedBox(height: 24.h),
                _buildLabel("Target value range"),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Min",
                        controller.minValueController,
                        keyboardType: TextInputType.number,
                        prefixText: "\$",
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      child: Text(
                        "—",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildTextField(
                        "Max",
                        controller.maxValueController,
                        keyboardType: TextInputType.number,
                        prefixText: "\$",
                      ),
                    ),
                  ],
                ),
              ]),

              SizedBox(height: 48.h),
              _buildPostButton(),
              SizedBox(height: 60.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: const Color(0xFF8B9BFF),
        fontSize: 22.sp,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildUploadBox() {
    return Obx(() {
      final images = controller.selectedImages;
      final selectedIndex = controller.selectedImageIndex.value;

      if (images.isEmpty) {
        return GestureDetector(
          onTap: () => controller.pickImages(),
          child: Container(
            height: 200.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  color: const Color(0xFF8B9BFF),
                  size: 32.sp,
                ),
                SizedBox(height: 12.h),
                Text(
                  "Upload prime visuals",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large Preview Area
          Container(
            height: 280.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    images[selectedIndex],
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 16.h,
                    right: 16.w,
                    child: GestureDetector(
                      onTap: () => controller.removeImage(selectedIndex),
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16.h,
                    left: 16.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        "Previewing ${selectedIndex + 1} of ${images.length}",
                        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Horizontal Thumbnail Row
          SizedBox(
            height: 68.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: images.length + 1,
              itemBuilder: (context, index) {
                if (index == images.length) {
                  // Add More Button at the end
                  return GestureDetector(
                    onTap: () => controller.pickImages(),
                    child: Container(
                      width: 60.h,
                      height: 60.h,
                      margin: EdgeInsets.only(top: 4.h, right: 10.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11111A),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF8B9BFF).withOpacity(0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: const Color(0xFF8B9BFF),
                            size: 18.sp,
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            "Add",
                            style: TextStyle(
                              color: const Color(0xFF8B9BFF),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => controller.selectedImageIndex.value = index,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60.h,
                        height: 60.h,
                        margin: EdgeInsets.only(top: 4.h, right: 10.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8B9BFF)
                                : Colors.white.withOpacity(0.1),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(
                            images[index],
                            fit: BoxFit.cover,
                            width: 60.h,
                            height: 60.h,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 6.w,
                        child: GestureDetector(
                          onTap: () => controller.removeImage(index),
                          child: Container(
                            padding: EdgeInsets.all(3.r),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildInputContainer(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 3.5.w,
            height: 13.h,
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController textController, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    String? prefixText,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: maxLines > 1 ? 12.h : 2.h,
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (prefixIcon != null) ...[
            Padding(
              padding: EdgeInsets.only(right: 10.w, top: maxLines > 1 ? 3.h : 0),
              child: prefixIcon,
            ),
          ],
          if (prefixText != null) ...[
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Text(
                prefixText,
                style: TextStyle(
                  color: const Color(0xFF8B9BFF),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          Expanded(
            child: TextField(
              controller: textController,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
          if (suffixText != null) ...[
            Padding(
              padding: EdgeInsets.only(left: 6.w),
              child: Text(
                suffixText,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (suffixIcon != null) ...[
            Padding(
              padding: EdgeInsets.only(left: 10.w),
              child: suffixIcon,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectable(
    String label,
    String value,
    VoidCallback onTap, {
    IconData? leadingIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, color: const Color(0xFF8B9BFF), size: 18.sp),
                  SizedBox(width: 10.w),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8B9BFF),
                    size: 18.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(
    String title,
    List<String> options,
    Function(String) onSelect,
  ) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 24.h),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: options.map((opt) {
                    IconData icon;
                    String listings;
                    switch (opt) {
                      case "Sneakers":
                        icon = Icons.directions_run;
                        listings = "1234 listings";
                        break;
                      case "Trading Cards":
                        icon = Icons.style;
                        listings = "892 listings";
                        break;
                      case "Tech":
                        icon = Icons.devices;
                        listings = "678 listings";
                        break;
                      case "Watches":
                        icon = Icons.watch;
                        listings = "456 listings";
                        break;
                      default:
                        icon = Icons.category_outlined;
                        listings = "0 listings";
                    }
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                      leading: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF8B9BFF),
                          size: 20.sp,
                        ),
                      ),
                      title: Text(
                        opt,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        listings,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        onSelect(opt);
                        Get.back();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPostButton() {
    return Container(
      width: double.infinity,
      height: 64.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B9BFF).withOpacity(0.3),
            blurRadius: 20.r,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Obx(
        () => ElevatedButton(
          onPressed: controller.isLoading.value
              ? null
              : () => controller.postTrade(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B9BFF),
            disabledBackgroundColor: const Color(0xFF8B9BFF).withOpacity(0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32.r),
            ),
            elevation: 0,
          ),
          child: controller.isLoading.value
              ? SizedBox(
                  width: 24.w,
                  height: 24.h,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  "Post Trade",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}
