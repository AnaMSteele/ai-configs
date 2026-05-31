const imageTagPattern = /<img\b[^>]*>/gi;

export interface ImageTagMatch {
  tag: string;
  src: string;
  srcAttribute: string;
  srcAttributeStart: number;
  srcAttributeEnd: number;
}

function findSrcAttribute(tag: string): Omit<ImageTagMatch, 'tag'> | undefined {
  let index = /^<img\b/i.test(tag) ? 4 : 0;
  while (index < tag.length) {
    while (/\s|\/|>/.test(tag[index] ?? '')) index += 1;
    const nameStart = index;
    while (index < tag.length && !/[\s=/>]/.test(tag[index])) index += 1;
    if (index === nameStart) break;
    const name = tag.slice(nameStart, index).toLowerCase();
    while (/\s/.test(tag[index] ?? '')) index += 1;
    if (tag[index] !== '=') continue;
    index += 1;
    while (/\s/.test(tag[index] ?? '')) index += 1;

    let src = '';
    if (tag[index] === '"' || tag[index] === "'") {
      const quote = tag[index];
      index += 1;
      const valueStart = index;
      while (index < tag.length && tag[index] !== quote) index += 1;
      src = tag.slice(valueStart, index);
      if (tag[index] === quote) index += 1;
    } else {
      const valueStart = index;
      while (index < tag.length && !/[\s/>]/.test(tag[index])) index += 1;
      src = tag.slice(valueStart, index);
    }

    if (name === 'src') {
      return {
        src,
        srcAttribute: tag.slice(nameStart, index),
        srcAttributeStart: nameStart,
        srcAttributeEnd: index
      };
    }
  }
  return undefined;
}

export function findImageSources(html: string): string[] {
  const sources: string[] = [];
  for (const tag of html.match(imageTagPattern) ?? []) {
    const match = findSrcAttribute(tag);
    if (match) sources.push(match.src);
  }
  return sources;
}

export function replaceImageTags(html: string, visitor: (match: ImageTagMatch) => string): string {
  return html.replace(imageTagPattern, tag => {
    const match = findSrcAttribute(tag);
    if (!match) return tag;
    return visitor({
      tag,
      src: match.src,
      srcAttribute: match.srcAttribute,
      srcAttributeStart: match.srcAttributeStart,
      srcAttributeEnd: match.srcAttributeEnd
    });
  });
}
