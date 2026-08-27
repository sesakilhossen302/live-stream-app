import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/messages_controller.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../data/services/api_url.dart';

class MessagesScreen extends GetView<MessagesController> {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(MessagesController());
    return CustomBackground(
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        "Messages",
                        style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF8B9BFF),
                    backgroundColor: const Color(0xFF161622),
                    onRefresh: () async {
                      await controller.fetchChatRooms();
                      await controller.fetchNotifications();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 24.h),
                        
                        // Search Bar
                        _buildSearchBar(),
                        
                        SizedBox(height: 32.h),
                        
                        // Filters
                        _buildFilters(),
                        
                        SizedBox(height: 32.h),
                        
                        Obx(() {
                          if (controller.isLoading.value) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader("UPDATES"),
                                SizedBox(height: 16.h),
                                _buildUpdateCardShimmer(),
                                _buildUpdateCardShimmer(),
                                SizedBox(height: 24.h),
                                _buildSectionHeader("MESSAGES"),
                                SizedBox(height: 16.h),
                                _buildMessageRowShimmer(),
                                _buildMessageRowShimmer(),
                                _buildMessageRowShimmer(),
                              ],
                            );
                          }

                          final updates = controller.filteredUpdates;
                          final chats = controller.filteredChats;

                          if (updates.isEmpty && chats.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 60.h),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(20.r),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF161622),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: const Color(0xFF8B9BFF),
                                        size: 40.sp,
                                      ),
                                    ),
                                    SizedBox(height: 20.h),
                                    Text(
                                      "No messages yet",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      "You don't have any conversations yet.\nStart chatting to trade or purchase items!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
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
                              if (updates.isNotEmpty) ...[
                                _buildSectionHeader("UPDATES", badge: "${updates.length} NEW"),
                                SizedBox(height: 16.h),
                                ...updates.map((up) => _buildUpdateCard(
                                  name: up['name'] ?? '',
                                  message: up['message'] ?? '',
                                  time: up['time'] ?? '',
                                  hasNew: up['hasNew'] == true,
                                  avatar: up['avatar'] ?? '',
                                  tags: List<String>.from(up['tags'] ?? []),
                                )),
                                SizedBox(height: 32.h),
                              ],

                              if (chats.isNotEmpty) ...[
                                _buildSectionHeader("MESSAGES"),
                                SizedBox(height: 16.h),
                                ...chats.map((ch) => _buildMessageRow(
                                  id: ch['id'] ?? '',
                                  name: ch['name'] ?? '',
                                  message: ch['message'] ?? '',
                                  time: ch['time'] ?? '',
                                  isSpecial: ch['isSpecial'] == true,
                                  avatar: ch['avatar'] ?? '',
                                  participantId: ch['participantId'] ?? '',
                                )),
                              ],
                            ],
                          );
                        }),
                        
                        SizedBox(height: 120.h),
                      ],
                    ),
                  ),
                ),
              ),
              ],
            ),
            
            // Floating Action Button
            Positioned(
              bottom: 30.h,
              right: 16.w,
              left: 16.w,
              child: Center(
                child: Container(
                  height: 60.h,
                  width: 60.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF8B9BFF).withOpacity(0.4), blurRadius: 20.r, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Icon(Icons.add, color: Colors.black, size: 32.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white, size: 24.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: TextField(
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: "Search conversations, orders, or trades...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 16.sp),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: List.generate(controller.filters.length, (index) {
        return Expanded(
          child: Obx(() {
            final isSelected = controller.selectedFilter.value == index;
            return GestureDetector(
              onTap: () => controller.changeFilter(index),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(28.r),
                ),
                child: Text(
                  controller.filters[index],
                  textAlign: Alignment.center.x == 0 ? TextAlign.center : null,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white38,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildSectionHeader(String title, {String? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
        if (badge != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(8.r)),
            child: Text(badge, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.w900)),
          ),
      ],
    );
  }

  Widget _buildUserAvatar(String avatarUrl, double size) {
    final String resolvedUrl = (avatarUrl.isNotEmpty && !avatarUrl.startsWith('http') && !avatarUrl.startsWith('data:image/'))
        ? "${ApiUrl.imageBaseUrl}${avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl'}"
        : avatarUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF28283E),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.3), width: 1.5),
      ),
      child: ClipOval(
        child: Builder(
          builder: (context) {
            if (resolvedUrl.isEmpty) {
              return Icon(Icons.person_rounded, color: Colors.white54, size: size * 0.55);
            }
            if (resolvedUrl.startsWith('data:image/') && resolvedUrl.contains('base64,')) {
              try {
                final bytes = base64Decode(resolvedUrl.split('base64,').last);
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: Colors.white54, size: size * 0.55),
                );
              } catch (_) {
                return Icon(Icons.person_rounded, color: Colors.white54, size: size * 0.55);
              }
            }
            return Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: Colors.white54, size: size * 0.55),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUpdateCard({required String name, required String message, required String time, required String avatar, List<String> tags = const [], bool hasNew = false}) {
    return InkWell(
      onTap: () => Get.toNamed(AppRoute.messageDetails),
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserAvatar(avatar, 48.r),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                          Row(
                            children: [
                              Text(time, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700)),
                              if (hasNew) ...[
                                SizedBox(width: 8.w),
                                Container(width: 8.h, height: 8.h, decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle)),
                              ],
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(message, style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                SizedBox(width: 64.w),
                ...tags.map((tag) => Container(
                  margin: EdgeInsets.only(right: 8.w),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10.r)),
                  child: Text(tag, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow({
    required String id,
    required String name,
    required String message,
    required String time,
    required String avatar,
    required String participantId,
    bool isSpecial = false,
  }) {
    return InkWell(
      onTap: () {
        controller.markRoomAsRead(id);
        Get.toNamed(AppRoute.messageDetails, arguments: {
          "chatId": id,
          "name": name,
          "avatar": avatar,
          "participantId": participantId,
        });
      },
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.only(bottom: 24.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserAvatar(avatar, 56.r),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                      Text(time, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSpecial ? const Color(0xFF8B9BFF) : Colors.white70,
                      fontSize: 14.sp,
                      fontWeight: isSpecial ? FontWeight.w900 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer.circular(width: 48.r, height: 48.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomShimmer.rectangular(height: 16.h, width: 100.w),
                        CustomShimmer.rectangular(height: 12.h, width: 40.w),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    CustomShimmer.rectangular(height: 14.h, width: 180.w),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              SizedBox(width: 64.w),
              CustomShimmer.rectangular(
                height: 24.h,
                width: 80.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              SizedBox(width: 8.w),
              CustomShimmer.rectangular(
                height: 24.h,
                width: 80.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRowShimmer() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomShimmer.circular(width: 56.r, height: 56.r),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomShimmer.rectangular(height: 16.h, width: 100.w),
                    CustomShimmer.rectangular(height: 12.h, width: 40.w),
                  ],
                ),
                SizedBox(height: 8.h),
                CustomShimmer.rectangular(height: 14.h, width: 220.w),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
