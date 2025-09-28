'use client';

import { useEffect, useMemo, useState } from 'react';
import Map, { Marker, NavigationControl } from 'react-map-gl';
import 'mapbox-gl/dist/mapbox-gl.css';
import type { DiningHall } from '@/models/types';

interface MapPanelProps {
  halls: DiningHall[];
  selectedHallId?: string;
  onSelectHall?: (hallId: string) => void;
}

const FALLBACK_CENTER: [number, number] = [-73.963, 40.8065];

export const MapPanel = ({ halls, selectedHallId, onSelectHall }: MapPanelProps) => {
  const mapToken = process.env.NEXT_PUBLIC_MAPBOX_TOKEN;
  const center = useMemo(() => {
    if (selectedHallId) {
      const hall = halls.find((item) => item.id === selectedHallId);
      if (hall) {
        return [hall.longitude, hall.latitude] as [number, number];
      }
    }
    if (halls.length > 0) {
      const avgLat = halls.reduce((sum, hall) => sum + hall.latitude, 0) / halls.length;
      const avgLng = halls.reduce((sum, hall) => sum + hall.longitude, 0) / halls.length;
      return [avgLng, avgLat] as [number, number];
    }
    return FALLBACK_CENTER;
  }, [halls, selectedHallId]);

  const [viewState, setViewState] = useState({ longitude: center[0], latitude: center[1], zoom: 15 });

  useEffect(() => {
    setViewState((prev) => ({ ...prev, longitude: center[0], latitude: center[1] }));
  }, [center[0], center[1]]);

  if (!mapToken) {
    return (
      <div className="surface-card--muted flex h-full flex-col items-center justify-center p-10 text-center text-sm text-white/60">
        Provide a Mapbox access token via NEXT_PUBLIC_MAPBOX_TOKEN to enable the live map. Until then, hall cards remain fully functional.
      </div>
    );
  }

  return (
    <Map
      mapboxAccessToken={mapToken}
      viewState={viewState}
      onMove={(evt) => setViewState(evt.viewState)}
      style={{ borderRadius: '28px', width: '100%', height: '100%' }}
      mapStyle="mapbox://styles/mapbox/navigation-night-v1"
    >
      <NavigationControl position="top-left" />
      {halls.map((hall) => (
        <Marker key={hall.id} longitude={hall.longitude} latitude={hall.latitude}>
          <button
            type="button"
            onClick={() => onSelectHall?.(hall.id)}
            className={`flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs font-semibold transition ${
              selectedHallId === hall.id
                ? 'border-white bg-white text-black shadow-[0_12px_40px_rgba(0,0,0,0.28)]'
                : 'border-white/20 bg-black/70 text-white/80 hover:border-white/40 hover:text-white'
            }`}
          >
            <span className={`h-2.5 w-2.5 rounded-full ${hall.isOpen ? 'bg-[#32d583]' : 'bg-white/40'}`} />
            {hall.name}
          </button>
        </Marker>
      ))}
    </Map>
  );
};
