/**
 * Type declarations for the packed-channel generator
 * (F-WEBINSTALL-FLASHALL-PICKER-TRUTH). Kept deliberately small: only the
 * surface the tests consume.
 */

export declare const INSTALLER_ROOT: string;

export interface PackedChannelRow {
  product: string;
  packed: boolean;
  sourceStamp: string | null;
  channelLabel: string | null;
  artifactCount: number;
}

export declare function readAllowedProducts(): string[];
export declare function packedChannelFor(product: string): {
  product: string;
  packed: true;
  sourceStamp: string;
  channelLabel: string;
  artifactCount: number;
} | null;
export declare function buildPackedChannels(): PackedChannelRow[];
