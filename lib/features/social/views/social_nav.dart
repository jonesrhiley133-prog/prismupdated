import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/social/views/compose_post_sheet.dart';
import 'package:prism_plurality/features/social/widgets/post_card.dart';

void openPost(BuildContext context, String id) =>
    context.push(AppRoutePaths.socialPost(id));
void openAlterBlog(BuildContext context, String memberId) =>
    context.push(AppRoutePaths.socialAlter(memberId));
void openTag(BuildContext context, String tag) =>
    context.push(AppRoutePaths.socialTag(tag));

PostCallbacks socialCallbacks(BuildContext context) => PostCallbacks(
  openPost: (id) => openPost(context, id),
  openAlter: (id) => openAlterBlog(context, id),
  openTag: (t) => openTag(context, t),
  compose: ({quote, edit, answer}) =>
      showComposePost(context, quote: quote, edit: edit, answer: answer),
);
