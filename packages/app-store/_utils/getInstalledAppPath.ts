import z from "zod";

import { AppCategories } from "@calcom/prisma/enums";

const variantSchema = z.nativeEnum(AppCategories);

export default function getInstalledAppPath(
  { variant, slug }: { variant?: string; slug?: string },
  locationSearch = ""
): string {
  if (!variant) return `/platform/apps/installed${locationSearch}`;

  const parsedVariant = variantSchema.safeParse(variant);

  if (!parsedVariant.success) return `/platform/apps/installed${locationSearch}`;

  if (!slug) return `/platform/apps/installed/${variant}${locationSearch}`;

  return `/platform/apps/installed/${variant}?hl=${slug}${locationSearch && locationSearch.slice(1)}`;
}
