String libraryLocation(String pageId, {required String title, String? url}) =>
    Uri(
      pathSegments: ['', 'library', pageId],
      queryParameters: {'title': title, 'url': ?url},
    ).toString();
