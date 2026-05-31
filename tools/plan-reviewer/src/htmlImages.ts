const imageTagPattern = /<img\b[^>]*>/gi;
const srcAttributePattern = /\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))/i;

export interface ImageTagMatch {
  tag: string;
  src: string;
  srcAttribute: string;
}

export function findImageSources(html: string): string[] {
  const sources: string[] = [];
  for (const tag of html.match(imageTagPattern) ?? []) {
    const match = srcAttributePattern.exec(tag);
    if (match) sources.push(match[1] ?? match[2] ?? match[3] ?? '');
  }
  return sources;
}

export function replaceImageTags(html: string, visitor: (match: ImageTagMatch) => string): string {
  return html.replace(imageTagPattern, tag => {
    const match = srcAttributePattern.exec(tag);
    if (!match) return tag;
    return visitor({
      tag,
      src: match[1] ?? match[2] ?? match[3] ?? '',
      srcAttribute: match[0]
    });
  });
}
