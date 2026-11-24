String libraryLocation(String pageId, {required String title, String? url}) =>
    Uri(
      pathSegments: ['', 'library', pageId],
      queryParameters: {'title': title, if (url != null) 'url': url},
    ).toString();
