import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chat/centralized_import.dart';

class UpdateAvailable extends StatefulWidget {
  bool? force;
  String storeUrl;
  String updateDescription;
  UpdateAvailable(
      {super.key,
      this.force,
      required this.storeUrl,
      required this.updateDescription});

  @override
  State<UpdateAvailable> createState() => _UpdateAvailableState();
}

class _UpdateAvailableState extends State<UpdateAvailable>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = context.height() < 600;
    final isTablet = context.width() > 600;

    return WillPopScope(
      onWillPop: () async {
        if (widget.force != true) {
          return true;
        }
        return false;
      },
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isTablet ? context.width() * 0.25 : 20,
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon with gradient background
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withOpacity(0.1),
                                    primaryColor.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.system_update,
                                size: isSmallScreen
                                    ? 56
                                    : isTablet
                                        ? 80
                                        : 68,
                                color: primaryColor,
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 20 : 24),

                            // Title with enhanced styling
                            Text(
                              'lblUpdateApp'.translate,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallScreen
                                    ? 20
                                    : isTablet
                                        ? 26
                                        : 22,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 8 : 12),

                            // Enhanced description
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                widget.updateDescription,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 24 : 32),

                            // Buttons with improved layout
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isVerySmall = constraints.maxWidth < 300;

                                if (isVerySmall || widget.force == true) {
                                  // Vertical layout for small screens or forced update
                                  return Column(
                                    children: [
                                      _buildUpdateButton(
                                          isSmallScreen, isTablet),
                                      if (widget.force != true)
                                        SizedBox(height: 16),
                                      if (widget.force != true)
                                        _buildSkipButton(
                                            isSmallScreen, isTablet),
                                    ],
                                  );
                                } else {
                                  // Horizontal layout for wider screens
                                  return Row(
                                    children: [
                                      if (widget.force != true)
                                        Expanded(
                                          child: _buildSkipButton(
                                              isSmallScreen, isTablet),
                                        ),
                                      if (widget.force != true)
                                        SizedBox(width: 16),
                                      Expanded(
                                        flex: widget.force == true ? 1 : 1,
                                        child: _buildUpdateButton(
                                            isSmallScreen, isTablet),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),

                        // Loading overlay
                        Observer(
                          builder: (context) {
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: appStore.isLoading
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: appStore.isLoading
                                  ? Center(
                                      child: Container(
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      primaryColor),
                                              strokeWidth: 3,
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Opening Store...',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : SizedBox.shrink(),
                            ).visible(appStore.isLoading);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton(bool isSmallScreen, bool isTablet) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 48 : 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: appStore.isLoading
              ? null
              : () {
                  if (Platform.isAndroid || Platform.isIOS) {
                    launchUrl(
                      Uri.parse(widget.storeUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download,
                  color: Colors.white,
                  size: isSmallScreen ? 18 : 20,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'lblUpdateBtn'.translate,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(bool isSmallScreen, bool isTablet) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 48 : 52,
      decoration: BoxDecoration(
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: appStore.isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              'lblSkip'.translate,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
